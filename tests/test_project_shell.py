import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SHELL = Path(__file__).resolve().parents[1] / 'bin/workspace-project-shell'


class ProjectShellTests(unittest.TestCase):
    def run_shell(self, answer=None, environments=()):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            (home / '.bashrc').write_text('export TEST_RC=loaded\n')
            for name in environments:
                folder = home / name / 'bin'
                folder.mkdir(parents=True)
                (folder / 'activate').write_text('export TEST_VENV=' + name + '\n')
            env = {k: v for k, v in os.environ.items() if k not in ('VIRTUAL_ENV', 'TEST_VENV', 'TEST_RC', 'BASH_ENV', 'PROMPT_COMMAND')}
            env.update(HOME=d, PS1='', PS2='')
            commands = ('\n' if answer == '' else answer + '\n') if answer is not None else ''
            commands += 'printf "RESULT:%s:%s\\n" "$TEST_RC" "${TEST_VENV:-none}"\nexit\n'
            return subprocess.run([str(SHELL)], cwd=d, env=env, input=commands, text=True, capture_output=True, timeout=5)

    def test_accept_dot_venv(self):
        result = self.run_shell('y', ['.venv'])
        self.assertEqual(result.returncode, 0)
        self.assertIn('RESULT:loaded:.venv', result.stdout)

    def test_accept_venv(self):
        self.assertIn('RESULT:loaded:venv', self.run_shell('yes', ['venv']).stdout)

    def test_enter_declines(self):
        self.assertIn('RESULT:loaded:none', self.run_shell('', ['.venv']).stdout)

    def test_no_declines(self):
        self.assertIn('RESULT:loaded:none', self.run_shell('n', ['venv']).stdout)

    def test_no_environment_has_no_prompt(self):
        result = self.run_shell()
        self.assertNotIn('Activate it?', result.stdout)
        self.assertIn('RESULT:loaded:none', result.stdout)

    def test_dot_venv_has_priority(self):
        self.assertIn('RESULT:loaded:.venv', self.run_shell('y', ['.venv', 'venv']).stdout)


if __name__ == '__main__':
    unittest.main()
