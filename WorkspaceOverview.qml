import QtQuick

Item {
  id: overview
  property var workspaces: []
  property string error: ""
  property color foreground: "#f6efe7"
  property color accent: "#e8743b"
  signal selected(int workspaceId)
  signal refreshRequested()
  function move(step) {
    list.currentIndex = Math.max(0, Math.min(list.count - 1, list.currentIndex + step))
    list.positionViewAtIndex(list.currentIndex, ListView.Contain)
  }
  function activateCurrent() {
    if (list.currentIndex >= 0 && list.currentIndex < workspaces.length) selected(workspaces[list.currentIndex].id)
  }

  Text {
    id: heading; text: "Your workspaces"; color: overview.foreground
    font.pixelSize: 22; font.bold: true
  }
  ActionButton { anchors.right: parent.right; text: "Refresh"; foreground: overview.foreground; onClicked: overview.refreshRequested() }
  Text {
    anchors.top: heading.bottom; anchors.topMargin: 8
    text: "Local projects and remote computers, together."
    color: overview.foreground; opacity: 0.6; font.pixelSize: 13
  }
  ListView {
    id: list
    anchors { top: heading.bottom; topMargin: 43; bottom: parent.bottom; left: parent.left; right: parent.right }
    clip: true; spacing: 10
    model: overview.workspaces
    currentIndex: 0
    boundsBehavior: Flickable.StopAtBounds
    delegate: Rectangle {
      id: row
      required property var modelData
      required property int index
      width: list.width; height: 90; radius: 14
      color: Qt.rgba(1, 1, 1, list.currentIndex === index ? 0.10 : 0.045)
      border.width: modelData.active ? 1 : 0
      border.color: overview.accent
      Text {
        x: 16; y: 13; width: parent.width - 180
        text: row.modelData.name; textFormat: Text.PlainText
        color: overview.foreground; font.pixelSize: 17; font.bold: true; elide: Text.ElideRight
      }
      Text {
        anchors { right: parent.right; rightMargin: 16; top: parent.top; topMargin: 15 }
        text: row.modelData.kind + (row.modelData.active ? " · here" : "")
        color: overview.accent; font.pixelSize: 12
      }
      Text {
        x: 16; y: 40; width: parent.width - 32
        text: row.modelData.windows.length ? row.modelData.windows.map(w => w.title).join("  ·  ") : "Empty workspace"
        textFormat: Text.PlainText; color: overview.foreground; opacity: 0.68
        font.pixelSize: 12; elide: Text.ElideRight
      }
      Text {
        x: 16; y: 63
        text: row.modelData.windows.length + " windows · " + row.modelData.monitor
        textFormat: Text.PlainText; color: overview.foreground; opacity: 0.42; font.pixelSize: 11
      }
      MouseArea {
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: list.currentIndex = row.index
        onClicked: overview.selected(row.modelData.id)
      }
    }
  }
  Text {
    anchors.centerIn: parent; width: parent.width - 40
    visible: overview.workspaces.length === 0
    text: overview.error || "No workspaces to show yet."
    textFormat: Text.PlainText; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
    color: overview.foreground; opacity: 0.6; font.pixelSize: 14
  }
}
