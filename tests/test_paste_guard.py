"""PasteGuard.qml: a paste that arrives late is used only if the field is unchanged.

The cases live in tests/paste-guard/shell.qml and run inside a throwaway
Quickshell instance, so this needs Quickshell and a Wayland session. Without
them the test is skipped. The real clipboard is not read.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = ['paste-arrives', 'dropped-after-edit', 'dropped-after-clear-and-refill',
            'dropped-after-form-change', 'dropped-when-hidden', 'second-paste-is-ignored']


class PasteGuardTests(unittest.TestCase):
    @unittest.skipUnless(shutil.which('quickshell') and os.environ.get('WAYLAND_DISPLAY'),
                         'needs Quickshell and a Wayland session')
    def test_late_paste_is_dropped_when_the_field_changed(self):
        with tempfile.TemporaryDirectory() as d:
            for name in ('PasteGuard.qml', 'BoundedRun.qml', 'tests/paste-guard/shell.qml'):
                shutil.copy(ROOT / name, d)
            done = subprocess.run(['quickshell', '--no-color', '-p', d], capture_output=True,
                                  text=True, timeout=60)
        log = done.stdout + done.stderr
        results = dict(re.findall(r'CASE (\S+) (PASS|FAIL)', log))
        for name in EXPECTED:
            with self.subTest(case=name):
                line = next((l for l in log.splitlines() if f'CASE {name} ' in l), 'no result')
                self.assertEqual(results.get(name), 'PASS', line)
        self.assertNotIn('FAIL', results.values(), log)


if __name__ == '__main__':
    unittest.main()
