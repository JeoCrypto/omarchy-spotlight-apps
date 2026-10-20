import QtQuick
import QtQuick.Controls

Button {
  id: control
  property color foreground: "#f6efe7"
  property color surface: "#37302a"
  property color accent: "#e8743b"
  property bool primary: false
  implicitHeight: 36
  implicitWidth: Math.max(84, label.implicitWidth + 28)
  opacity: enabled ? 1 : 0.4
  contentItem: Text {
    id: label
    text: control.text
    textFormat: Text.PlainText
    color: control.primary ? "#1c1917" : control.foreground
    font.pixelSize: 13
    font.weight: Font.DemiBold
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
  background: Rectangle {
    radius: 9
    color: control.primary ? control.accent : control.surface
    border.width: control.activeFocus ? 2 : 0
    border.color: control.accent
    opacity: control.down ? 0.7 : control.hovered ? 0.85 : 1
  }
}
