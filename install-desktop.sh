#!/usr/bin/env bash
# Install Spotlight, Workspace Presets and the backup widget with backups.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
"$here/install-presets.sh"
python3 - "$here" <<'PY'
from pathlib import Path
import datetime
import json
import os
import shutil
import sys
import tempfile
source = Path(sys.argv[1])
config = Path(os.environ.get('XDG_CONFIG_HOME', Path.home() / '.config')) / 'omarchy'
state = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'omarchy'
backup = state / 'workspace-presets-backups' / datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f')
backup.mkdir(parents=True)
plugin = config / 'plugins/io.github.jeocrypto.launchpad'
if plugin.exists():
    shutil.copytree(plugin, backup / 'spotlight', ignore=shutil.ignore_patterns('.git', '*.webp', '*.jpg', '*.png'))
plugin.mkdir(parents=True, exist_ok=True)
for name in ['Launchpad.qml', 'ActionButton.qml', 'PresetEditor.qml', 'WorkspaceOverview.qml', 'BackupPanel.qml', 'manifest.json']:
    target = plugin / name
    if (source / name).resolve() != target.resolve():
        shutil.copy2(source / name, target)
widget = config / 'plugins/jeo.backup'
if widget.exists():
    shutil.copytree(widget, backup / 'backup-widget')
widget.mkdir(parents=True, exist_ok=True)
for name in ['BarWidget.qml', 'manifest.json']:
    shutil.copy2(source / 'addons/jeo.backup' / name, widget / name)
shell_path = config / 'shell.json'
settings = json.loads(shell_path.read_text())
shutil.copy2(shell_path, backup / 'shell.json')
right = settings['bar']['layout']['right']
if not any(entry['id'] == 'jeo.backup' for entries in settings['bar']['layout'].values() for entry in entries):
    right.insert(1, {'id': 'jeo.backup'})
fd, tmp = tempfile.mkstemp(prefix='.shell-', dir=config)
try:
    with os.fdopen(fd, 'w') as out:
        json.dump(settings, out, indent=2)
        out.write('\n')
    os.replace(tmp, shell_path)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
print('Installed desktop additions. Backup:', backup)
PY
