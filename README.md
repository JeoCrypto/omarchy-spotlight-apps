<p align="center">
  <img src="banner.jpg" alt="Spotlight Apps, for Omarchy" width="100%">
</p>

<p align="center">
  <b>A floating, frosted, macOS Spotlight-style app panel for <a href="https://omarchy.org">Omarchy</a>.</b><br>
  Find your apps · launch project workspaces · see your desktop · check your backups
</p>

<p align="center">
  <img alt="Omarchy 4" src="https://img.shields.io/badge/Omarchy-4-e8743b?style=flat-square&labelColor=1c1917">
  <img alt="Omarchy shell plugin" src="https://img.shields.io/badge/shell%20plugin-Quickshell-e8743b?style=flat-square&labelColor=1c1917">
  <img alt="MIT licence" src="https://img.shields.io/badge/licence-MIT-e8743b?style=flat-square&labelColor=1c1917">
</p>

<p align="center">
  <img src="demo.webp" alt="Spotlight Apps demo: opening from the dock, browsing categories, searching and launching an app" width="100%">
</p>

<p align="center">
  <a href="#get-started">Get started</a> ·
  <a href="#workspace-presets">Workspace presets</a> ·
  <a href="#your-desktop-at-a-glance">Desktop overview</a> ·
  <a href="#backup-status">Backups</a> ·
  <a href="#keys">Shortcuts</a>
</p>

## Get started

**1. Install the plugin**

```bash
omarchy plugin add https://github.com/JeoCrypto/omarchy-spotlight-apps --enable
```

**2. Give it a key** in `~/.config/hypr/bindings.lua` (`SUPER + A` is free in Omarchy's defaults):

```lua
o.bind("SUPER + A", "Spotlight Apps", "omarchy-shell shell toggle io.github.jeocrypto.launchpad")
```

**3. Frost the glass** (recommended) in `~/.config/hypr/looknfeel.lua`:

```lua
hl.layer_rule({ match = { namespace = "^launchpad$" }, blur = true, ignore_alpha = 0.2 })
```

**4. Add workspace tools and the backup widget** (optional):

```bash
cd ~/.config/omarchy/plugins/io.github.jeocrypto.launchpad
./install-desktop.sh
```

This installs the helper commands and backup widget, with backups of the affected shell configuration. It preserves existing presets. For presets and the overview without adding a bar widget, run `./install-presets.sh` instead. See [Requirements](#requirements) for the additional dependencies.

The demo above shows app search and settings; the workspace tools below are included in version 1.3.

## Highlights

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>🔎 Search as you type</h3>
      Start typing the moment it opens. Apps match by name, generic name and keywords, so "calc" finds the calculator. Settings and saved workspace presets show up too. Search for <code>project remote</code> to find the included Remote preset.
    </td>
    <td width="50%" valign="top">
      <h3>🗂️ Browse by category</h3>
      All, Settings, Development, Office, Media, Internet, Games, System, Utilities and Web Apps, worked out from each app's desktop categories.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>⚙️ Omarchy settings, one tap away</h3>
      Coloured tiles open Omarchy's own panels and menus: Wi-Fi, Bluetooth, Sound, Display, Power, Theme, Background, Font, Keybindings, Monitors, Input, Setup and Updates.
    </td>
    <td valign="top">
      <h3>🪶 Light and sharp</h3>
      Loads only while it's open, so it uses no memory the rest of the time. Icons load at device resolution on HiDPI screens, and the colours follow your Omarchy theme.
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>🗂️ Projects, ready to work</h3>
      Create a preset with a folder, website and layout. Open its files, browser and terminal together, then return to the same workspace whenever you need it.
    </td>
    <td valign="top">
      <h3>🖥️ A view of your whole desk</h3>
      Browse local and remote workspaces with their window names. Check your Restic job from the Backups page or its companion bar icon.
    </td>
  </tr>
</table>

Your pinned apps sit in a suggested row above every app in alphabetical order. The row is shared with [Glass Dock](https://github.com/JeoCrypto/omarchy-glass-dock). Hidden apps match Omarchy's own Apps menu (`launcher.hides`).

## Workspace presets

Open a project’s files, browser and terminal together on a dedicated workspace, with a Snap Layout. Choose it again to return to the same workspace without launching duplicates.

If you skipped the optional desktop installation, install the helpers from the repository or installed plugin directory (requires Python 3 and [Snap Layouts](https://github.com/JeoCrypto/omarchy-snap-layouts)):

```bash
./install-presets.sh
```

Press **Super + A**, choose **Workspaces**, then **New preset**. To edit or rename one, select it and choose **Edit selected**. Deleting a preset asks for confirmation and leaves its open windows running. You can also search for presets by name. The included **Omarchy Remote** example uses `~/Work/omarchy-remote`, Strata, Chromium and Foot; edit it to match your machine before opening it.

Presets live in `~/.config/omarchy/workspace-presets.json` (or under `XDG_CONFIG_HOME`). Each preset has a unique `id`, a display `name`, a `directory`, a Snap Layout (`halves`, `sixty`, `seventy`, `thirds`, `center`, or `grid`) and an ordered `apps` array. See the [complete example](examples/workspace-presets.json).

Each app has an `argv` array and a `match` regular expression for its Hyprland window class. `~` and environment variables expand in arguments and directories; arguments are treated literally rather than as shell code. An optional app `cwd` overrides the preset directory. Use commands that open a **new window**; commands that reuse an existing window will time out. Apps open in order, and the last app becomes the main Snap Layout window.

```bash
workspace-presets validate             # check config, directories and commands
workspace-presets list                 # list presets as JSON
workspace-presets open omarchy-remote  # open from a terminal or keybinding
```

Workspaces are named `project-<id>`. If any windows remain there, opening the preset resumes that workspace and preserves your arrangement; it does not recreate individual missing apps. Close all its windows to start it afresh. Startup errors leave already opened windows intact and show a notification. If you switch away during startup, the helper skips the layout step.

Project terminals can use `workspace-project-shell` as their command, for example `"argv": ["foot", "--app-id=project.omarchy-remote.terminal", "workspace-project-shell"]`. It opens interactive Bash with your usual `~/.bashrc`, then asks **Activate it? [y/N]** if the project contains `.venv/bin/activate` or `venv/bin/activate` (preferring `.venv` if both exist). Press `y` to activate, or Enter to continue without activation. No environment means no prompt; resuming a workspace keeps its existing terminal. This is enabled in the included Remote preset.

Spotlight reads presets each time it opens. Files and code are local to your computer; the website is opened in your browser. Presets do not commit or push project changes.

## Your desktop at a glance

Choose **Overview** in Spotlight to browse local, project and remote workspaces with their window names. Click a workspace, or use arrows and Enter, to switch. The list refreshes every five seconds while open; scratchpads are omitted.

The overview shows window names rather than live thumbnails. It switches focus without moving or closing windows.

## Backup status

Choose **Backups**, or click the companion backup bar icon, to see the last confirmed Restic snapshot, last attempt and next scheduled run. You can request a backup or open the job’s logs from this page.

The bar icon shows an attention mark after a failed/interrupted backup or a confirmed snapshot older than two days. Right-click it to refresh. It reads local job state and systemd metadata, never backup credentials or the remote repository.

The installer does **not** set up a Restic repository, schedule a backup, or modify your backup script. It expects the existing `restic-backup.service` and `restic-backup.timer` user units. Add the tracking calls below to your job to record confirmed snapshots. Until then, historical successes are shown as **Not recorded yet**.

### Recording confirmed snapshots

Call these at the corresponding stages of your backup job:

```bash
workspace-desktop record start
# Run restic backup; only after it succeeds:
workspace-desktop record snapshot
# After retention finishes, record its final exit code (0 means success):
workspace-desktop record finish 0
```

Record a nonzero finish code from your failure/exit handler if the job fails. A snapshot saved before a retention failure remains recorded as the last successful snapshot. History before tracking was enabled is shown as **Not recorded yet**. State lives in `~/.local/state/omarchy/backup-status.json` (or under `XDG_STATE_HOME`). The status page expects the `restic-backup.service` and `restic-backup.timer` user units; the tracker works with manual runs too.

## Keys

| Key | Action |
|---|---|
| Type | Search apps, settings and saved presets |
| `←` `↑` `↓` `→` | Move the selection |
| `Enter` | Open the selection or switch to the selected workspace |
| `Tab` / `Shift+Tab` | Next / previous category |
| `Esc` | Clear the search, then return to All, then close |
| `Ctrl+N` | Create a workspace preset |
| `Ctrl+E` | Edit the selected preset in Workspaces |

Click an app to open it. Click outside the panel, or the × button, to close it.

## Configure

| File | What it does |
|---|---|
| `~/.config/omarchy/workspace-presets.json` | Saved presets. Edit through Spotlight or customize app commands in this file. |
| `~/.local/state/omarchy/backup-status.json` | Snapshot and job status written by the backup tracker. |
| `~/.config/glass-dock/pinned` | The suggested row: one desktop-file id per line (shared with Glass Dock). Without it, Files, Chromium and Foot are suggested. |

The Settings tiles, the categories and the sizes are defined at the top of `Launchpad.qml`.

**Open it from Glass Dock's app-grid button:**

```bash
mkdir -p ~/.config/glass-dock
echo "omarchy-shell shell toggle io.github.jeocrypto.launchpad" > ~/.config/glass-dock/launcher
```

## Update and remove

```bash
omarchy plugin update io.github.jeocrypto.launchpad
cd ~/.config/omarchy/plugins/io.github.jeocrypto.launchpad
./install-presets.sh   # refresh helper commands if you use the workspace tools
omarchy restart shell
```

If you installed the backup widget, re-run `./install-desktop.sh` instead of `./install-presets.sh` to update it too. Your presets are preserved. The plugin ID is `io.github.jeocrypto.launchpad`, its original name.

To remove the plugins:

```bash
omarchy plugin remove jeo.backup  # if installed
omarchy plugin remove io.github.jeocrypto.launchpad
```

Helper commands and your preset/state files are left in place. Remove `workspace-presets`, `workspace-project-shell` and `workspace-desktop` from `~/.local/bin` when you no longer need them, and remove any tracking calls you added to your backup job.

## Requirements

- Omarchy 4 (Hyprland 0.55+ with Lua config, Quickshell 0.3+)
- `uwsm` and `gtk-launch`, which Omarchy includes
- A Nerd Font for the settings glyphs (Omarchy's default monospace fonts include them)
- Workspace tools: Python 3, Bash, [Snap Layouts](https://github.com/JeoCrypto/omarchy-snap-layouts) and Foot
- Preset editor defaults: Strata or Nautilus for files; Chromium, Chrome or Firefox for websites. Custom app commands can be configured in the preset file.
- Backup page: an existing Restic job with the user units and tracking calls described above

## Development

```bash
python3 -m unittest discover -s tests -v
bash -n install-presets.sh install-desktop.sh bin/workspace-project-shell
```

Tests cover preset creation/editing/deletion, stale edits, workspace selection, virtual-environment prompts and backup state. They do not launch real desktop apps or run a real backup.

---

<p align="center">
  <b>Part of the Golden Gate set for Omarchy</b><br>
  <a href="https://github.com/JeoCrypto/omarchy-golden-gate-theme">Golden Gate theme</a> ·
  <a href="https://github.com/JeoCrypto/omarchy-glass-dock">Glass Dock</a> ·
  <a href="https://github.com/JeoCrypto/omarchy-spotlight-apps">Spotlight Apps</a> ·
  <a href="https://github.com/JeoCrypto/omarchy-snap-layouts">Snap Layouts</a>
</p>

<p align="center"><sub>MIT licence</sub></p>
