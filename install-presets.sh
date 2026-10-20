#!/bin/bash
# Install Workspace Presets for Spotlight Apps; keep an existing preset file.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy"
mkdir -p "$HOME/.local/bin" "$config_dir"
install -m755 "$here/bin/workspace-presets" "$HOME/.local/bin/workspace-presets"
install -m755 "$here/bin/workspace-project-shell" "$HOME/.local/bin/workspace-project-shell"
install -m755 "$here/bin/workspace-desktop" "$HOME/.local/bin/workspace-desktop"
if [[ ! -e $config_dir/workspace-presets.json ]]; then
  install -m644 "$here/examples/workspace-presets.json" "$config_dir/workspace-presets.json"
fi
printf 'Installed workspace-presets. Edit %s/workspace-presets.json for your apps and folders.\n' "$config_dir"
