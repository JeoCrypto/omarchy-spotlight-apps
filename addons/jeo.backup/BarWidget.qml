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

  // The status helper runs through BoundedRun: a time limit, capped output,
  // one report per run (also when it cannot be started) and nothing left behind.
  function refresh() { probe.start() }
  BoundedRun {
    id: probe
    seconds: 20
    maxBytes: 65536
    argv: [Quickshell.env("HOME") + "/.local/bin/workspace-desktop", "backup"]
    onFinished: function(code, output, errors) {
      try { root.status = JSON.parse(output) }
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
