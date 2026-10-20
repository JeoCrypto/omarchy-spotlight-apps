import QtQuick

Item {
  id: panel
  property var status: ({label: "Checking backup status…", lastSuccess: "—", lastAttempt: "—", nextRun: "—"})
  property string message: ""
  property color foreground: "#f6efe7"
  property color accent: "#e8743b"
  property bool busy: false
  signal refreshRequested()
  signal startRequested()
  signal logsRequested()

  Column {
    width: parent.width; spacing: 22
    Text { text: "Backups"; color: panel.foreground; font.pixelSize: 25; font.bold: true }
    Rectangle {
      width: parent.width; height: 90; radius: 16
      color: Qt.rgba(panel.accent.r, panel.accent.g, panel.accent.b, 0.09)
      Column {
        anchors { fill: parent; margins: 18 }
        spacing: 8
        Text {
          text: panel.status.label || "Status unavailable"; textFormat: Text.PlainText
          color: ["failed", "interrupted", "overdue"].indexOf(panel.status.status) >= 0 ? "#f08880" : panel.accent
          font.pixelSize: 20; font.bold: true
        }
        Text { text: "Restic · scheduled daily"; color: panel.foreground; opacity: 0.6; font.pixelSize: 13 }
      }
    }
    Repeater {
      model: [{label: "Last confirmed snapshot", value: panel.status.lastSuccess},
              {label: "Last attempt", value: panel.status.lastAttempt},
              {label: "Next scheduled run", value: panel.status.nextRun}]
      Column {
        required property var modelData
        width: panel.width; spacing: 6
        Text { text: parent.modelData.label; color: panel.foreground; opacity: 0.5; font.pixelSize: 12 }
        Text { text: parent.modelData.value || "Unavailable"; textFormat: Text.PlainText; color: panel.foreground; font.pixelSize: 15; width: parent.width; elide: Text.ElideRight }
      }
    }
    Text {
      width: parent.width; height: 38; wrapMode: Text.WordWrap; textFormat: Text.PlainText
      text: panel.message || panel.status.detail || panel.status.error || "Your backup history stays on this computer."
      color: panel.foreground; opacity: 0.65; font.pixelSize: 13
    }
    Row {
      spacing: 10
      ActionButton {
        text: "Back up now"; primary: true; accent: panel.accent
        enabled: !panel.busy && !!panel.status.serviceAvailable && panel.status.status !== "running"
        onClicked: panel.startRequested()
      }
      ActionButton { text: "View logs"; foreground: panel.foreground; onClicked: panel.logsRequested() }
      ActionButton { text: "Refresh"; foreground: panel.foreground; enabled: !panel.busy; onClicked: panel.refreshRequested() }
    }
  }
}
