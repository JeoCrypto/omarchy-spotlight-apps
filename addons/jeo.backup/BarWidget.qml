import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "jeo.backup"
  property var status: ({status: "unknown", label: "Checking backups…"})
  readonly property bool warning: ["failed", "interrupted", "overdue"].indexOf(status.status) >= 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function refresh() { if (!probe.running) probe.running = true }
  Process {
    id: probe
    command: [Quickshell.env("HOME") + "/.local/bin/workspace-desktop", "backup"]
    stdout: StdioCollector { id: output; waitForEnd: true }
    onExited: function(code) {
      try { root.status = JSON.parse(output.text) }
      catch (e) { root.status = {status: "unknown", label: "Backup status unavailable"} }
    }
  }
  Timer { interval: 60000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: String.fromCodePoint(0xF06F7) + (root.warning ? " !" : root.status.status === "running" ? " …" : "")
    foreground: root.warning ? "#f08880" : root.status.status === "running" ? "#e9b96e" : (root.bar ? root.bar.barForeground : Commons.Color.foreground)
    tooltipText: (root.status.label || "Backup status unavailable") + "\nLast snapshot: " + (root.status.lastSuccess || "Not recorded yet") + "\nNext: " + (root.status.nextRun || "Unavailable")
    onPressed: function(button) {
      if (button === Qt.RightButton) root.refresh()
      else Quickshell.execDetached(["omarchy-shell", "shell", "summon", "io.github.jeocrypto.launchpad", JSON.stringify({page: "Backups"})])
    }
  }
}
