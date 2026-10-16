// Launchpad: a full-screen, frosted, macOS-style app grid for Omarchy.
//
// An Omarchy shell "panel" plugin that loads only while open:
//   omarchy-shell shell toggle io.github.jeocrypto.launchpad
//
// Shows pinned apps (shared with Glass Dock's ~/.config/glass-dock/pinned),
// then folders grouped from each app's desktop categories, plus a Settings
// folder that opens Omarchy's own panels and menus. Type to search; arrows,
// Enter and Esc to navigate. Hidden apps match Omarchy's own Apps menu.

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets

Item {
  id: root

  // Injected by the Omarchy shell.
  property string omarchyPath: ""
  property var shell: null
  property var manifest: null

  property bool opened: false
  readonly property string home: Quickshell.env("HOME")
  readonly property string pluginId: manifest && manifest.id ? manifest.id : "io.github.jeocrypto.launchpad"

  // ---- Geometry (logical px, whole numbers so edges land on pixels) ----
  // 56 px icons load at 112 device pixels on a 2x screen, below the 128 px
  // most themes ship, so they're scaled down (sharp) rather than up (soft).
  readonly property int iconSize: 56
  readonly property int cellWidth: 116
  readonly property int cellHeight: 112
  readonly property int maxColumns: 7

  // ---- Theme: every colour in the active Omarchy theme's colors.toml ----
  property var palette: ({
    background: "#1c1917", foreground: "#e9e1d8", bright_foreground: "#f6efe7", accent: "#e8743b",
    red: "#e0675f", green: "#9fbf7a", yellow: "#e9b96e", blue: "#7fa4c9", magenta: "#c49ac4",
    cyan: "#86b8b0", orange: "#e8743b"
  })
  readonly property color bg: palette.background
  readonly property color fg: palette.bright_foreground || palette.foreground
  readonly property color accent: palette.accent

  function tint(name) { return palette[name] || palette.accent }
  function alpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  FileView {
    id: themeColors
    path: root.home + "/.local/state/omarchy/current/theme/colors.toml"
    __printErrors: false
    onLoaded: {
      const next = Object.assign({}, root.palette)
      const re = /^([a-z_]+)\s*=\s*"(#[0-9a-fA-F]{6})"/gm
      let m
      while ((m = re.exec(text())) !== null) next[m[1]] = m[2]
      root.palette = next
    }
  }

  // ---- Apps Omarchy hides from its Apps menu ----
  property var hiddenIds: ({})

  FileView {
    path: Quickshell.env("OMARCHY_PATH") + "/default/omarchy/launcher.hides"
    __printErrors: false
    onLoaded: {
      const map = {}
      for (const line of text().split("\n")) if (line.trim()) map[line.trim()] = true
      root.hiddenIds = map
    }
  }

  // ---- Pinned apps, shared with Glass Dock ----
  readonly property var defaultPinned: ["org.gnome.Nautilus", "chromium", "foot"]
  property var pinned: defaultPinned

  FileView {
    path: root.home + "/.config/glass-dock/pinned"
    __printErrors: false
    onLoaded: root.pinned = text().split("\n").map(s => s.trim()).filter(s => s && !s.startsWith("#"))
    onLoadFailed: root.pinned = root.defaultPinned
  }

  // ---- Settings folder: Omarchy's own panels and menus ----
  // glyph: Nerd Font codepoint; tint: theme colour name.
  readonly property var settingsItems: [
    { kind: "setting", name: "Wi-Fi",       glyph: 0xF05A9, tint: "blue",    cmd: "omarchy-shell shell toggle omarchy.network" },
    { kind: "setting", name: "Bluetooth",   glyph: 0xF00AF, tint: "blue",    cmd: "omarchy-shell shell toggle omarchy.bluetooth" },
    { kind: "setting", name: "Sound",       glyph: 0xF057E, tint: "red",     cmd: "omarchy-shell shell toggle omarchy.audio" },
    { kind: "setting", name: "Display",     glyph: 0xF0379, tint: "cyan",    cmd: "omarchy-shell shell toggle omarchy.monitor" },
    { kind: "setting", name: "Power",       glyph: 0xF0079, tint: "green",   cmd: "omarchy-shell shell toggle omarchy.power" },
    { kind: "setting", name: "Theme",       glyph: 0xF0E0C, tint: "accent",  cmd: "omarchy-menu summon style.theme" },
    { kind: "setting", name: "Background",  glyph: 0xF0E09, tint: "magenta", cmd: "omarchy-menu summon style.background" },
    { kind: "setting", name: "Font",        glyph: 0xF0B34, tint: "yellow",  cmd: "omarchy-menu summon style.font" },
    { kind: "setting", name: "Keybindings", glyph: 0xF030C, tint: "magenta", cmd: "omarchy-menu summon setup.keybindings" },
    { kind: "setting", name: "Monitors",    glyph: 0xF037A, tint: "cyan",    cmd: "omarchy-menu summon setup.monitors" },
    { kind: "setting", name: "Input",       glyph: 0xF037D, tint: "green",   cmd: "omarchy-menu summon setup.input" },
    { kind: "setting", name: "Setup",       glyph: 0xF0493, tint: "accent",  cmd: "omarchy-menu summon setup" },
    { kind: "setting", name: "Updates",     glyph: 0xF06B0, tint: "orange",  cmd: "omarchy-menu summon update" }
  ]

  // Folder order, and the desktop categories that put an app in each one.
  readonly property var folderRules: [
    { name: "Settings",    categories: ["Settings"] },
    { name: "Development", categories: ["Development", "IDE"] },
    { name: "Office",      categories: ["Office"] },
    { name: "Media",       categories: ["AudioVideo", "Audio", "Video", "Graphics"] },
    { name: "Internet",    categories: ["Network", "WebBrowser", "Email", "Chat"] },
    { name: "Games",       categories: ["Game"] },
    { name: "System",      categories: ["System"] },
    { name: "Utilities",   categories: ["Utility"] }
  ]

  function iconSource(icon) {
    const value = String(icon || "")
    if (value.startsWith("/")) return "file://" + value
    return Quickshell.iconPath(value, "application-x-executable")
  }

  function appItem(e) {
    return { kind: "app", id: e.id, name: e.name, icon: e.icon,
             search: [e.name, e.genericName || "", (e.keywords || []).join(" ")].join(" ").toLowerCase() }
  }

  // Every visible app, sorted by name.
  readonly property var apps: {
    const out = []
    const seen = {}
    for (const e of DesktopEntries.applications.values) {
      if (!e || e.noDisplay || hiddenIds[e.id] || seen[e.id]) continue
      seen[e.id] = true
      out.push(e)
    }
    out.sort((a, b) => a.name.localeCompare(b.name))
    return out
  }

  // Pinned apps first, then folders. Single-app folders show the app itself.
  readonly property var topItems: {
    const pinnedEntries = []
    const pinnedIds = {}
    for (const id of pinned) {
      const e = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
      if (e && !pinnedIds[e.id]) { pinnedIds[e.id] = true; pinnedEntries.push(appItem(e)) }
    }

    const folders = folderRules.map(r => ({ kind: "folder", name: r.name, items: [] }))
    const webApps = { kind: "folder", name: "Web Apps", items: [] }
    folders[0].items = settingsItems.slice()

    for (const e of apps) {
      if (pinnedIds[e.id]) continue
      const cats = e.categories || []
      let placed = false
      for (let i = 0; i < folderRules.length && !placed; i++) {
        if (folderRules[i].categories.some(c => cats.indexOf(c) !== -1)) {
          folders[i].items.push(appItem(e))
          placed = true
        }
      }
      if (!placed) webApps.items.push(appItem(e))
    }
    folders.push(webApps)

    const loose = []
    const kept = []
    for (const f of folders) {
      if (f.items.length === 1) loose.push(f.items[0])
      else if (f.items.length > 1) kept.push(f)
    }
    loose.sort((a, b) => a.name.localeCompare(b.name))
    return pinnedEntries.concat(loose, kept)
  }

  // ---- Search ----
  property string query: ""

  readonly property var results: {
    const q = query.trim().toLowerCase()
    if (!q) return []
    const pool = apps.map(appItem).concat(settingsItems.map(s => Object.assign({ search: s.name.toLowerCase() }, s)))
    const scored = []
    for (const item of pool) {
      const name = item.name.toLowerCase()
      let score = -1
      if (name.startsWith(q)) score = 0
      else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) score = 1
      else if (name.includes(q)) score = 2
      else if (item.search.includes(q)) score = 3
      if (score >= 0) scored.push({ score: score, item: item })
    }
    scored.sort((a, b) => a.score - b.score || a.item.name.localeCompare(b.item.name))
    return scored.map(s => s.item)
  }

  // ---- State ----
  property var openFolder: null
  property int currentIndex: 0
  property int folderIndex: 0

  readonly property var gridItems: query.trim() ? results : topItems

  onQueryChanged: currentIndex = 0

  function open(payloadJson) {
    themeColors.reload()
    query = ""
    openFolder = null
    currentIndex = 0
    opened = true
  }

  function close() {
    opened = false
  }

  // Ask the shell to hide (and unload) us, so nothing stays in memory.
  function dismiss() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else close()
  }

  function activate(item) {
    if (!item) return
    if (item.kind === "folder") {
      openFolder = item
      folderIndex = 0
      return
    }
    if (item.kind === "app") Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", item.id])
    else if (item.kind === "setting") Quickshell.execDetached(["bash", "-lc", item.cmd])
    dismiss()
  }

  function columnsFor(width, count) {
    return Math.max(1, Math.min(maxColumns, Math.floor(width / cellWidth), count))
  }

  function move(dx, dy) {
    if (openFolder) {
      const n = openFolder.items.length
      const cols = folderGrid.columns
      folderIndex = Math.max(0, Math.min(n - 1, folderIndex + dx + dy * cols))
    } else {
      const n = gridItems.length
      const cols = mainGrid.columns
      currentIndex = Math.max(0, Math.min(n - 1, currentIndex + dx + dy * cols))
      mainGrid.positionViewAtIndex(currentIndex, GridView.Contain)
    }
  }

  PanelWindow {
    id: window
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "launchpad"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    onVisibleChanged: if (visible) { content.opacity = 0; content.scale = 0.98; appear.start(); search.forceActiveFocus() }

    // Frosted backdrop (Hyprland blurs the "launchpad" layer); click to close.
    Rectangle {
      anchors.fill: parent
      color: root.alpha(root.bg, 0.55)
      MouseArea {
        anchors.fill: parent
        onClicked: root.openFolder ? root.openFolder = null : root.dismiss()
      }
    }

    Item {
      id: content
      anchors.fill: parent
      transformOrigin: Item.Center

      ParallelAnimation {
        id: appear
        NumberAnimation { target: content; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: content; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
      }

      // ---- Search field ----
      Rectangle {
        id: searchBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: 64
        width: 440
        height: 40
        radius: 20
        color: root.alpha(root.fg, 0.08)
        border.width: 0.5
        border.color: root.alpha(root.fg, 0.16)

        Text {
          id: glass
          anchors.verticalCenter: parent.verticalCenter
          x: 16
          text: String.fromCodePoint(0xF0349)
          color: root.alpha(root.fg, 0.55)
          font.family: "monospace"
          font.pixelSize: 16
        }

        TextInput {
          id: search
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: glass.right
          anchors.leftMargin: 10
          anchors.right: parent.right
          anchors.rightMargin: 16
          focus: true
          color: root.fg
          selectionColor: root.alpha(root.accent, 0.45)
          font.family: "sans-serif"
          font.pixelSize: 15
          clip: true
          text: root.query
          onTextEdited: root.query = text

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !search.text
            text: "Search"
            color: root.alpha(root.fg, 0.45)
            font: search.font
          }

          Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
              if (root.openFolder) root.openFolder = null
              else if (root.query) root.query = ""
              else root.dismiss()
            } else if (e.key === Qt.Key_Left) root.move(-1, 0)
            else if (e.key === Qt.Key_Right) root.move(1, 0)
            else if (e.key === Qt.Key_Up) root.move(0, -1)
            else if (e.key === Qt.Key_Down) root.move(0, 1)
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
              if (root.openFolder) root.activate(root.openFolder.items[root.folderIndex])
              else root.activate(root.gridItems[root.currentIndex])
            } else return
            e.accepted = true
          }
        }
      }

      // ---- Main grid ----
      GridView {
        id: mainGrid
        readonly property int columns: root.columnsFor(parent.width - 160, root.gridItems.length)
        anchors.top: searchBox.bottom
        anchors.topMargin: 48
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        anchors.horizontalCenter: parent.horizontalCenter
        width: columns * root.cellWidth
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        model: root.gridItems
        visible: root.gridItems.length > 0
        // Fade the grid behind an open folder, like macOS
        opacity: root.openFolder ? 0.15 : 1
        Behavior on opacity { NumberAnimation { duration: 140 } }

        delegate: Tile {
          required property var modelData
          required property int index
          item: modelData
          current: !root.openFolder && index === root.currentIndex
          onHovered: if (!root.openFolder) root.currentIndex = index
          onActivated: root.activate(modelData)
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: searchBox.bottom
        anchors.topMargin: 80
        visible: root.query.trim() !== "" && root.results.length === 0
        text: "No results"
        color: root.alpha(root.fg, 0.5)
        font.family: "sans-serif"
        font.pixelSize: 15
      }

      // ---- Open folder ----
      Rectangle {
        anchors.fill: parent
        visible: root.openFolder !== null
        color: root.alpha(root.bg, 0.35)

        MouseArea {
          anchors.fill: parent
          onClicked: root.openFolder = null
        }

        Rectangle {
          id: folderCard
          anchors.centerIn: parent
          width: folderGrid.width + 48
          height: folderTitle.height + folderGrid.height + 64
          radius: 24
          color: root.alpha(root.bg, 0.96)
          border.width: 0.5
          border.color: root.alpha(root.fg, 0.14)

          MouseArea { anchors.fill: parent }

          Text {
            id: folderTitle
            anchors.horizontalCenter: parent.horizontalCenter
            y: 20
            text: root.openFolder ? root.openFolder.name : ""
            color: root.fg
            font.family: "sans-serif"
            font.pixelSize: 18
            font.weight: Font.DemiBold
          }

          GridView {
            id: folderGrid
            readonly property var items: root.openFolder ? root.openFolder.items : []
            readonly property int columns: root.columnsFor(window.width - 240, Math.min(5, items.length))
            readonly property int rows: Math.ceil(items.length / Math.max(1, columns))
            x: 24
            anchors.top: folderTitle.bottom
            anchors.topMargin: 20
            width: columns * root.cellWidth
            height: Math.min(rows, 4) * root.cellHeight
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            clip: true
            interactive: rows > 4
            model: items

            delegate: Tile {
              required property var modelData
              required property int index
              item: modelData
              current: index === root.folderIndex
              onHovered: root.folderIndex = index
              onActivated: root.activate(modelData)
            }
          }
        }
      }
    }
  }

  // ---- One grid cell: app, setting or folder ----
  component Tile: Item {
    id: tile
    property var item: null
    property bool current: false
    signal hovered()
    signal activated()

    width: root.cellWidth
    height: root.cellHeight

    Rectangle {
      x: 8; y: 4
      width: parent.width - 16
      height: parent.height - 8
      radius: 16
      color: root.alpha(root.fg, tile.current ? 0.12 : 0)
      Behavior on color { ColorAnimation { duration: 100 } }
    }

    // App icon
    IconImage {
      visible: tile.item && tile.item.kind === "app"
      x: (parent.width - root.iconSize) / 2
      y: 12
      implicitSize: root.iconSize
      source: visible ? root.iconSource(tile.item.icon) : ""
      asynchronous: true
    }

    // Settings tile: coloured rounded square with a vector glyph
    GlyphTile {
      visible: tile.item && tile.item.kind === "setting"
      x: (parent.width - root.iconSize) / 2
      y: 12
      size: root.iconSize
      setting: visible ? tile.item : null
    }

    // Folder: frosted square with up to four miniatures
    Rectangle {
      visible: tile.item && tile.item.kind === "folder"
      x: (parent.width - root.iconSize) / 2
      y: 12
      width: root.iconSize
      height: root.iconSize
      radius: 16
      color: root.alpha(root.fg, 0.14)
      border.width: 0.5
      border.color: root.alpha(root.fg, 0.18)

      Grid {
        anchors.centerIn: parent
        columns: 2
        spacing: 4
        Repeater {
          model: tile.item && tile.item.kind === "folder" ? tile.item.items.slice(0, 4) : []
          Item {
            required property var modelData
            width: 22; height: 22
            IconImage {
              visible: modelData.kind === "app"
              anchors.fill: parent
              implicitSize: 22
              source: visible ? root.iconSource(modelData.icon) : ""
              asynchronous: true
            }
            GlyphTile {
              visible: modelData.kind === "setting"
              size: 22
              setting: visible ? modelData : null
            }
          }
        }
      }
    }

    Text {
      x: 8
      y: 12 + root.iconSize + 8
      width: parent.width - 16
      text: tile.item ? tile.item.name : ""
      color: root.fg
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      maximumLineCount: 2
      elide: Text.ElideRight
      font.family: "sans-serif"
      font.pixelSize: 12
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.activated()
    }

    // MouseArea hover doesn't fire for warped pointers; HoverHandler does.
    HoverHandler {
      onHoveredChanged: if (hovered) tile.hovered()
    }
  }

  component GlyphTile: Rectangle {
    id: glyphTile
    property var setting: null
    property int size: 64
    width: size
    height: size
    radius: Math.round(size / 4)
    readonly property color base: setting ? root.tint(setting.tint) : root.accent
    gradient: Gradient {
      GradientStop { position: 0; color: Qt.lighter(glyphTile.base, 1.18) }
      GradientStop { position: 1; color: Qt.darker(glyphTile.base, 1.12) }
    }

    Text {
      anchors.centerIn: parent
      text: glyphTile.setting ? String.fromCodePoint(glyphTile.setting.glyph) : ""
      color: "#ffffff"
      font.family: "monospace"
      font.pixelSize: Math.round(glyphTile.size * 0.52)
    }
  }
}
