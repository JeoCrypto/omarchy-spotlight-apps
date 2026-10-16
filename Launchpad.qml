// Spotlight Apps: a floating, frosted, macOS Spotlight-style app panel for Omarchy.
//
// An Omarchy shell "panel" plugin that loads only while open:
//   omarchy-shell shell toggle io.github.jeocrypto.launchpad
//
// A rounded glass card with a search field, category chips, a row of
// suggested apps (shared with Glass Dock's ~/.config/glass-dock/pinned) and
// every app in alphabetical order. The Settings category opens Omarchy's own
// panels and menus. Type to search; arrows and Enter to launch; Tab to switch
// category; Esc to clear or close. Hidden apps match Omarchy's own Apps menu.

import QtQuick
import QtQuick.Effects
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
  readonly property int columns: 7
  readonly property int cellWidth: 100
  readonly property int cellHeight: 100
  readonly property int padding: 28
  readonly property int cardWidth: columns * cellWidth + padding * 2
  readonly property int cardHeight: 600

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

  // ---- Suggested apps: Glass Dock's pinned list ----
  readonly property var defaultPinned: ["org.gnome.Nautilus", "chromium", "foot"]
  property var pinned: defaultPinned

  FileView {
    path: root.home + "/.config/glass-dock/pinned"
    __printErrors: false
    onLoaded: root.pinned = text().split("\n").map(s => s.trim()).filter(s => s && !s.startsWith("#"))
    onLoadFailed: root.pinned = root.defaultPinned
  }

  // ---- Settings: Omarchy's own panels and menus ----
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

  // Category chips, in order, and the desktop categories behind each one.
  // An app belongs to the first category it matches; apps with no category
  // (Omarchy's web apps and TUIs) go to "Web Apps".
  readonly property var categoryRules: [
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

  function categoryOf(e) {
    const cats = e.categories || []
    for (const r of categoryRules)
      if (r.categories.some(c => cats.indexOf(c) !== -1)) return r.name
    return "Web Apps"
  }

  function appItem(e) {
    return { kind: "app", id: e.id, name: e.name, icon: e.icon, category: categoryOf(e),
             generic: String(e.genericName || "").toLowerCase(),
             search: [e.name, e.genericName || "", (e.keywords || []).join(" ")].join(" ").toLowerCase() }
  }

  // Every visible app, sorted by name.
  readonly property var apps: {
    const out = []
    const seen = {}
    for (const e of DesktopEntries.applications.values) {
      if (!e || e.noDisplay || hiddenIds[e.id] || seen[e.id]) continue
      seen[e.id] = true
      out.push(appItem(e))
    }
    out.sort((a, b) => a.name.localeCompare(b.name))
    return out
  }

  readonly property var suggested: {
    const out = []
    const seen = {}
    for (const id of pinned) {
      const e = DesktopEntries.byId(id) || DesktopEntries.heuristicLookup(id)
      if (e && !seen[e.id] && !hiddenIds[e.id]) { seen[e.id] = true; out.push(appItem(e)) }
      if (out.length === columns) break
    }
    return out
  }

  // "All", then every category that has something in it.
  readonly property var chips: {
    const out = ["All"]
    for (const r of categoryRules.concat([{ name: "Web Apps" }])) {
      if (r.name === "Settings" || apps.some(a => a.category === r.name)) out.push(r.name)
    }
    return out
  }

  // ---- State ----
  property string query: ""
  property string chip: "All"
  property int currentIndex: 0

  readonly property bool searching: query.trim() !== ""

  readonly property var results: {
    const q = query.trim().toLowerCase()
    if (!q) return []
    const pool = apps.concat(settingsItems.map(s => Object.assign({ search: s.name.toLowerCase() }, s)))
    const scored = []
    for (const item of pool) {
      const name = item.name.toLowerCase()
      let score = -1
      if (name.startsWith(q)) score = 0
      // "calc" should find the Calculator (generic name) as readily as LibreOffice Calc
      else if ((item.generic || "").startsWith(q)) score = 0
      else if (name.split(/[\s\-_.]+/).some(w => w.startsWith(q))) score = 1
      else if (name.includes(q)) score = 2
      else if (item.search.includes(q)) score = 3
      if (score >= 0) scored.push({ score: score, item: item })
    }
    scored.sort((a, b) => a.score - b.score || a.item.name.localeCompare(b.item.name))
    return scored.map(s => s.item)
  }

  // True while the first grid row is the suggested row (with a divider below).
  readonly property bool showSuggested: !searching && chip === "All" && suggested.length > 0

  // The grid model. The suggested row is padded with spacers to a full row so
  // the alphabetical list always starts on a fresh row under the divider.
  readonly property var gridItems: {
    if (searching) return results
    if (chip === "Settings") return settingsItems.concat(apps.filter(a => a.category === "Settings"))
    if (chip !== "All") return apps.filter(a => a.category === chip)
    if (!showSuggested) return apps
    const row = suggested.slice()
    while (row.length < columns) row.push({ kind: "spacer", name: "" })
    return row.concat(apps)
  }

  onQueryChanged: currentIndex = firstSelectable(0, 1)
  onChipChanged: currentIndex = firstSelectable(0, 1)

  function selectable(i) { return i >= 0 && i < gridItems.length && gridItems[i].kind !== "spacer" }

  function firstSelectable(from, step) {
    for (let i = from; i >= 0 && i < gridItems.length; i += step) if (selectable(i)) return i
    return -1
  }

  function open(payloadJson) {
    themeColors.reload()
    query = ""
    chip = "All"
    currentIndex = firstSelectable(0, 1)
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
    if (!item || item.kind === "spacer") return
    if (item.kind === "app") Quickshell.execDetached(["uwsm-app", "--", "gtk-launch", item.id])
    else if (item.kind === "setting") Quickshell.execDetached(["bash", "-lc", item.cmd])
    dismiss()
  }

  function move(dx, dy) {
    if (currentIndex < 0) { currentIndex = firstSelectable(0, 1); return }
    let next = currentIndex + dx + dy * columns
    next = Math.max(0, Math.min(gridItems.length - 1, next))
    // Skip spacers in the suggested row, in the direction of travel.
    if (!selectable(next)) next = firstSelectable(next, dx < 0 || dy < 0 ? -1 : 1)
    if (next < 0) next = firstSelectable(currentIndex + (dy > 0 ? columns : 0), 1)
    if (next >= 0) {
      currentIndex = next
      grid.positionViewAtIndex(currentIndex, GridView.Contain)
    }
  }

  function cycleChip(step) {
    query = ""
    const i = chips.indexOf(chip)
    chip = chips[(i + step + chips.length) % chips.length]
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

    onVisibleChanged: if (visible) { card.opacity = 0; card.scale = 0.96; appear.start(); search.forceActiveFocus() }

    // Clicking anywhere outside the card closes it.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: root.cardWidth
      height: root.cardHeight
      radius: 28
      // Hyprland blurs the "launchpad" layer behind the card (ignore_alpha
      // skips the transparent area around it).
      color: root.alpha(root.bg, 0.78)
      border.width: 0.5
      border.color: root.alpha(root.fg, 0.16)
      transformOrigin: Item.Center

      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowOpacity: 0.45
        shadowBlur: 1.0
        shadowVerticalOffset: 12
        autoPaddingEnabled: true
      }

      ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 190; easing.type: Easing.OutCubic }
      }

      // Swallow clicks on the card itself.
      MouseArea { anchors.fill: parent }

      // ---- Header: search ----
      Item {
        id: header
        x: root.padding
        y: 20
        width: parent.width - root.padding * 2
        height: 36

        Text {
          id: glass
          anchors.verticalCenter: parent.verticalCenter
          text: String.fromCodePoint(0xF0349)
          color: root.alpha(root.fg, 0.6)
          font.family: "monospace"
          font.pixelSize: 20
        }

        TextInput {
          id: search
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: glass.right
          anchors.leftMargin: 12
          anchors.right: closeButton.left
          anchors.rightMargin: 12
          focus: true
          color: root.fg
          selectionColor: root.alpha(root.accent, 0.45)
          font.family: "sans-serif"
          font.pixelSize: 22
          clip: true
          text: root.query
          onTextEdited: root.query = text

          Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !search.text
            text: "Search apps"
            color: root.alpha(root.fg, 0.4)
            font: search.font
          }

          Keys.onPressed: (e) => {
            if (e.key === Qt.Key_Escape) {
              if (root.query) root.query = ""
              else if (root.chip !== "All") root.chip = "All"
              else root.dismiss()
            } else if (e.key === Qt.Key_Tab) root.cycleChip(1)
            else if (e.key === Qt.Key_Backtab) root.cycleChip(-1)
            else if (e.key === Qt.Key_Left) root.move(-1, 0)
            else if (e.key === Qt.Key_Right) root.move(1, 0)
            else if (e.key === Qt.Key_Up) root.move(0, -1)
            else if (e.key === Qt.Key_Down) root.move(0, 1)
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) root.activate(root.gridItems[root.currentIndex])
            else return
            e.accepted = true
          }
        }

        // Close button
        Rectangle {
          id: closeButton
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: 28; height: 28; radius: 14
          color: root.alpha(root.fg, closeHover.hovered ? 0.14 : 0.07)
          Text {
            anchors.centerIn: parent
            text: String.fromCodePoint(0xF0156)
            color: root.alpha(root.fg, 0.7)
            font.family: "monospace"
            font.pixelSize: 14
          }
          HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
          MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
        }
      }

      // ---- Category chips ----
      Flickable {
        id: chipStrip
        x: root.padding
        y: header.y + header.height + 14
        width: parent.width - root.padding * 2
        height: 30
        contentWidth: chipRow.width
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Row {
          id: chipRow
          spacing: 8
          Repeater {
            model: root.chips
            Rectangle {
              id: chipItem
              required property string modelData
              readonly property bool active: !root.searching && root.chip === modelData
              height: 30
              width: chipLabel.implicitWidth + 28
              radius: 15
              color: active ? root.alpha(root.accent, 0.9) : root.alpha(root.fg, chipHover.hovered ? 0.13 : 0.08)
              Behavior on color { ColorAnimation { duration: 120 } }
              onActiveChanged: if (active) chipStrip.contentX = Math.max(0, Math.min(x - 40, chipStrip.contentWidth - chipStrip.width))

              Text {
                id: chipLabel
                anchors.centerIn: parent
                text: chipItem.modelData
                color: chipItem.active ? root.bg : root.alpha(root.fg, 0.85)
                font.family: "sans-serif"
                font.pixelSize: 13
                font.weight: chipItem.active ? Font.DemiBold : Font.Normal
              }
              HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
              MouseArea { anchors.fill: parent; onClicked: { root.query = ""; root.chip = chipItem.modelData } }
            }
          }
        }
      }

      // ---- App grid ----
      GridView {
        id: grid
        x: root.padding
        y: chipStrip.y + chipStrip.height + 14
        width: root.columns * root.cellWidth
        height: parent.height - y - 16
        cellWidth: root.cellWidth
        cellHeight: root.cellHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.gridItems

        // Hairline under the suggested row
        Rectangle {
          parent: grid.contentItem
          visible: root.showSuggested
          x: 8
          y: root.cellHeight - 1
          width: grid.width - 16
          height: 0.5
          color: root.alpha(root.fg, 0.16)
        }

        delegate: Tile {
          required property var modelData
          required property int index
          item: modelData
          current: index === root.currentIndex
          onHovered: if (root.selectable(index)) root.currentIndex = index
          onActivated: root.activate(modelData)
        }
      }

      // Thin scroll indicator
      Rectangle {
        visible: grid.contentHeight > grid.height
        x: parent.width - 10
        y: grid.y + grid.visibleArea.yPosition * grid.height
        width: 3
        height: Math.max(24, grid.visibleArea.heightRatio * grid.height)
        radius: 1.5
        color: root.alpha(root.fg, 0.3)
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: grid.y + 40
        visible: root.searching && root.results.length === 0
        text: "No results"
        color: root.alpha(root.fg, 0.5)
        font.family: "sans-serif"
        font.pixelSize: 15
      }
    }
  }

  // ---- One grid cell: app or setting ----
  component Tile: Item {
    id: tile
    property var item: null
    property bool current: false
    signal hovered()
    signal activated()

    readonly property bool isSpacer: !item || item.kind === "spacer"
    width: root.cellWidth
    height: root.cellHeight

    Rectangle {
      visible: !tile.isSpacer
      x: 6; y: 2
      width: parent.width - 12
      height: parent.height - 6
      radius: 14
      color: root.alpha(root.fg, tile.current ? 0.12 : 0)
      Behavior on color { ColorAnimation { duration: 100 } }
    }

    IconImage {
      visible: tile.item && tile.item.kind === "app"
      x: (parent.width - root.iconSize) / 2
      y: 8
      implicitSize: root.iconSize
      source: visible ? root.iconSource(tile.item.icon) : ""
      asynchronous: true
    }

    GlyphTile {
      visible: tile.item && tile.item.kind === "setting"
      x: (parent.width - root.iconSize) / 2
      y: 8
      size: root.iconSize
      setting: visible ? tile.item : null
    }

    Text {
      visible: !tile.isSpacer
      x: 4
      y: 8 + root.iconSize + 7
      width: parent.width - 8
      text: tile.item ? tile.item.name : ""
      color: root.fg
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
      font.family: "sans-serif"
      font.pixelSize: 12
    }

    MouseArea {
      enabled: !tile.isSpacer
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: tile.activated()
    }

    // MouseArea hover doesn't fire for warped pointers; HoverHandler does.
    HoverHandler {
      enabled: !tile.isSpacer
      onHoveredChanged: if (hovered) tile.hovered()
    }
  }

  component GlyphTile: Rectangle {
    id: glyphTile
    property var setting: null
    property int size: 56
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
