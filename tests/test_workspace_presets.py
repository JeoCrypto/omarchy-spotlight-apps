import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

loader = importlib.machinery.SourceFileLoader('presets', str(Path(__file__).resolve().parents[1] / 'bin/workspace-presets'))
spec = importlib.util.spec_from_loader(loader.name, loader)
m = importlib.util.module_from_spec(spec)
loader.exec_module(m)


def preset():
    return {'id': 'demo', 'name': 'Demo', 'directory': '~', 'layout': 'sixty',
            'apps': [{'argv': ['foot'], 'match': '^foot$'}]}


class PresetTests(unittest.TestCase):
    def test_invalid_config_is_rejected(self):
        for modify in [lambda p: p.update(id='../bad'),
                       lambda p: p.update(layout='unknown'),
                       lambda p: p['apps'][0].update(argv='foot'),
                       lambda p: p['apps'][0].update(match='[')]:
            with self.subTest(modify=modify), tempfile.TemporaryDirectory() as d:
                p = preset()
                modify(p)
                path = Path(d) / 'presets.json'
                path.write_text(json.dumps([p]))
                with self.assertRaises((ValueError, m.re.error)):
                    m.load(path)

    def test_resume_does_not_launch_or_rearrange(self):
        with patch.object(m, 'hypr', return_value=[{'workspace': {'name': 'project-demo'}}]), \
             patch.object(m, 'dispatch') as dispatch, patch.object(m, 'plan') as plan:
            self.assertEqual(m.launch(preset()), 'Resumed Demo')
            plan.assert_not_called()
            self.assertEqual(dispatch.call_count, 1)
            self.assertIn('focus', dispatch.call_args.args[0])

    def test_preflight_failure_changes_nothing(self):
        with patch.object(m, 'hypr', return_value=[]), \
             patch.object(m, 'plan', side_effect=ValueError('Command not found')), \
             patch.object(m, 'dispatch') as dispatch:
            with self.assertRaises(ValueError):
                m.launch(preset())
            dispatch.assert_not_called()

    def test_new_matching_window_moves_but_existing_one_does_not(self):
        old = {'address': '0x1', 'class': 'foot', 'workspace': {'name': '1'}}
        new = {'address': '0x2', 'class': 'foot', 'workspace': {'name': '1'}}
        responses = [[old], [old], [old, new], {'name': 'project-demo'}]
        with patch.object(m, 'hypr', side_effect=responses), \
             patch.object(m, 'plan', return_value=[(['foot', "a; $(touch nope)"], Path('/tmp'), '^foot$')]), \
             patch.object(m, 'dispatch') as dispatch, patch.object(m.subprocess, 'run') as run:
            m.launch(preset())
            moves = [c.args[0] for c in dispatch.call_args_list if 'window.move' in c.args[0]]
            self.assertEqual(len(moves), 1)
            self.assertIn('address:0x2', moves[0])
            self.assertIn('follow = false', moves[0])
            command = next(c.args[0] for c in dispatch.call_args_list if 'exec_cmd' in c.args[0])
            self.assertIn("'a; $(touch nope)'", command)
            run.assert_called_once_with(['snap-layout', 'sixty'], check=True, timeout=10)

    def test_switching_away_skips_layout_and_focus(self):
        new = {'address': '0x2', 'class': 'foot'}
        with patch.object(m, 'hypr', side_effect=[[], [], [new], {'name': 'other'}]), \
             patch.object(m, 'plan', return_value=[(['foot'], Path('/tmp'), '^foot$')]), \
             patch.object(m, 'dispatch') as dispatch, patch.object(m.subprocess, 'run') as run:
            m.launch(preset())
            run.assert_not_called()
            self.assertFalse(any('focus({ window' in c.args[0] for c in dispatch.call_args_list))

    def test_timeout_leaves_other_windows_untouched(self):
        with patch.object(m, 'hypr', return_value=[]), \
             patch.object(m, 'plan', return_value=[(['foot'], Path('/tmp'), '^foot$')]), \
             patch.object(m.time, 'monotonic', side_effect=[0, 13]), \
             patch.object(m, 'dispatch') as dispatch:
            with self.assertRaisesRegex(RuntimeError, 'No new window'):
                m.launch(preset())
            self.assertFalse(any('window.move' in c.args[0] for c in dispatch.call_args_list))


if __name__ == '__main__':
    unittest.main()
