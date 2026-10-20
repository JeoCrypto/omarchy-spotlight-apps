import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


def module(name, filename):
    loader = importlib.machinery.SourceFileLoader(name, str(Path(__file__).resolve().parents[1] / 'bin' / filename))
    spec = importlib.util.spec_from_loader(name, loader)
    result = importlib.util.module_from_spec(spec)
    loader.exec_module(result)
    return result


presets = module('managed_presets', 'workspace-presets')
desktop = module('desktop_features', 'workspace-desktop')


class ManagementTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'presets.json'
        self.commands = patch.object(presets.shutil, 'which', return_value='/bin/true')
        self.commands.start()
        self.addCleanup(self.commands.stop)

    def draft(self, name='Example'):
        data = presets.form(self.path)
        data.update(name=name, directory=self.temp.name, url='https://example.com')
        return data

    def test_create_rename_and_delete_with_backups(self):
        result = presets.manage(self.path, 'save', self.draft())
        self.assertEqual(result['id'], 'example')
        data = presets.form(self.path, 'example')
        data['name'] = 'Renamed workspace'
        presets.manage(self.path, 'save', data)
        saved = presets.load(self.path)
        self.assertEqual(saved[0]['id'], 'example')
        self.assertEqual(saved[0]['name'], 'Renamed workspace')
        self.assertIn('workspace-project-shell', saved[0]['apps'][-1]['argv'])
        presets.manage(self.path, 'delete', presets.form(self.path, 'example'))
        self.assertEqual(presets.load(self.path), [])
        self.assertEqual(len(list(self.path.parent.glob('presets.json.bak.*'))), 2)

    def test_stale_edit_cannot_overwrite_another_edit(self):
        old = self.draft()
        presets.manage(self.path, 'save', old)
        with self.assertRaisesRegex(ValueError, 'changed'):
            presets.manage(self.path, 'save', old)
        self.assertEqual(len(presets.load(self.path)), 1)

    def test_invalid_directory_does_not_replace_config(self):
        data = self.draft()
        data['directory'] = str(self.path.parent / 'missing')
        with self.assertRaisesRegex(ValueError, 'Directory does not exist'):
            presets.manage(self.path, 'save', data)
        self.assertFalse(self.path.exists())

    def test_duplicate_names_get_distinct_ids(self):
        presets.manage(self.path, 'save', self.draft())
        result = presets.manage(self.path, 'save', self.draft())
        self.assertEqual(result['id'], 'example-2')

    def test_custom_apps_survive_form_edits(self):
        presets.manage(self.path, 'save', self.draft())
        data = presets.load(self.path)
        custom = {'argv': ['custom-editor', 'file with spaces'], 'match': '^editor$', 'cwd': '~'}
        data[0]['apps'].append(custom)
        presets.write_presets(self.path, data)
        form = presets.form(self.path, 'example')
        self.assertEqual(form['customApps'], 1)
        presets.manage(self.path, 'save', form)
        self.assertIn(custom, presets.load(self.path)[0]['apps'])


class BackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'backup.json'
        self.service = patch.object(desktop, 'properties', return_value={})
        self.service.start()
        self.addCleanup(self.service.stop)

    def test_unknown_is_not_reported_as_success(self):
        result = desktop.backup_status(self.path)
        self.assertEqual(result['status'], 'unknown')
        self.assertEqual(result['lastSuccess'], 'Not recorded yet')

    def test_failed_backup_preserves_previous_success(self):
        desktop.record(self.path, 'start')
        desktop.record(self.path, 'snapshot')
        desktop.record(self.path, 'finish')
        previous = desktop.read_state(self.path)['last_success']
        desktop.record(self.path, 'start')
        desktop.record(self.path, 'finish', 1)
        self.assertEqual(desktop.read_state(self.path)['last_success'], previous)
        self.assertEqual(desktop.backup_status(self.path)['status'], 'failed')

    def test_retention_failure_reports_snapshot_saved(self):
        desktop.record(self.path, 'start')
        desktop.record(self.path, 'snapshot')
        desktop.record(self.path, 'finish', 1)
        self.assertIn('retention failed', desktop.backup_status(self.path)['detail'])

    def test_old_success_is_flagged(self):
        self.path.write_text(json.dumps({'status': 'success', 'last_success': 1}))
        self.assertEqual(desktop.backup_status(self.path)['status'], 'overdue')

    def test_manual_live_job_is_running_even_with_inactive_service(self):
        desktop.record(self.path, 'start')
        with patch.object(desktop, 'properties', return_value={'ActiveState': 'inactive'}):
            self.assertEqual(desktop.backup_status(self.path)['status'], 'running')

    def test_service_failure_overrides_previous_success(self):
        desktop.record(self.path, 'snapshot')
        desktop.record(self.path, 'finish')
        with patch.object(desktop, 'properties', return_value={'Result': 'exit-code'}):
            self.assertEqual(desktop.backup_status(self.path)['status'], 'failed')


class OverviewTests(unittest.TestCase):
    def test_named_workspace_focus_uses_name_not_relative_id(self):
        with patch.object(desktop, 'run', side_effect=[json.dumps([{'id': -9, 'name': 'project-code'}]), 'ok']) as run:
            desktop.focus_workspace(-9)
        self.assertIn('name:project-code', run.call_args.args[0][-1])

    def test_closed_workspace_cannot_redirect_focus(self):
        with patch.object(desktop, 'run', return_value='[]') as run:
            with self.assertRaisesRegex(ValueError, 'closed'):
                desktop.focus_workspace(-9)
        self.assertEqual(run.call_count, 1)

    def test_overview_groups_windows_and_omits_scratchpads(self):
        responses = [
            [{'id': 1, 'name': '1', 'monitor': 'DP-1'}, {'id': -9, 'name': 'project-code'},
             {'id': -10, 'name': 'office'}, {'id': -99, 'name': 'special:scratchpad'}],
            [{'workspace': {'id': -10}, 'class': 'omarchy-remote-office', 'title': 'Desktop'},
             {'workspace': {'id': -9}, 'class': 'foot', 'title': '<plain text>'}],
            {'id': -9}]
        with patch.object(desktop, 'run', side_effect=[json.dumps(v) for v in responses]):
            result = desktop.workspace_overview()
        self.assertEqual(len(result), 3)
        self.assertTrue(result[0]['active'])
        self.assertEqual(result[0]['kind'], 'Project')
        self.assertEqual(next(w for w in result if w['id'] == -10)['kind'], 'Remote')
        self.assertEqual(result[0]['windows'][0]['title'], '<plain text>')


if __name__ == '__main__':
    unittest.main()
