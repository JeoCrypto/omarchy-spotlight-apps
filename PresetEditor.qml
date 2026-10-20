import QtQuick
import QtQuick.Controls

Rectangle {
  id: editor
  visible: false
  radius: 20
  color: backgroundColor
  property color backgroundColor: "#211d1a"
  property color foreground: "#f6efe7"
  property color accent: "#e8743b"
  property var original: ({})
  property bool busy: false
  property bool confirmDelete: false
  property string error: ""
  readonly property var layouts: ["sixty", "halves", "seventy", "thirds", "center", "grid"]
  readonly property var layoutNames: ["60 / 40", "Halves", "70 / 30", "Three columns", "Center focus", "Grid"]
  property int layoutIndex: 0
  signal saveRequested(var data)
  signal deleteRequested(var data)
  signal cancelled()

  function show(data) {
    original = data
    nameField.text = data.name
    directoryField.text = data.directory
    websiteField.text = data.url
    terminalCheck.checked = data.terminal
    filesCheck.checked = data.files
    layoutIndex = Math.max(0, layouts.indexOf(data.layout))
    error = ""
    busy = false
    confirmDelete = false
    visible = true
    nameField.forceActiveFocus()
  }
  function draft() {
    return { originalId: original.originalId, revision: original.revision,
      name: nameField.text, directory: directoryField.text,
      url: websiteField.text, layout: layouts[layoutIndex],
      terminal: terminalCheck.checked, files: filesCheck.checked }
  }

  MouseArea { anchors.fill: parent }
  Keys.onEscapePressed: editor.cancelled()

  Column {
    anchors { fill: parent; margins: 24 }
    spacing: 12
    Text {
      text: editor.original.originalId ? "Edit workspace preset" : "New workspace preset"
      color: editor.foreground; font.pixelSize: 23; font.bold: true
    }
    Text {
      text: "Give your project a place to work."
      color: editor.foreground; opacity: 0.6; font.pixelSize: 13
    }
    Field { id: nameField; width: parent.width; label: "Name"; placeholder: "My development workspace" }
    Field { id: directoryField; width: parent.width; label: "Project folder"; placeholder: "~/Work/my-project" }
    Field { id: websiteField; width: parent.width; label: "Website (optional)"; placeholder: "https://github.com/you/project" }
    Row {
      spacing: 14
      ActionButton {
        text: "Layout: " + editor.layoutNames[editor.layoutIndex]
        foreground: editor.foreground; accent: editor.accent
        onClicked: editor.layoutIndex = (editor.layoutIndex + 1) % editor.layouts.length
      }
      CheckBox {
        id: filesCheck; text: "Files"; palette.windowText: editor.foreground
        palette.buttonText: editor.foreground; palette.highlight: editor.accent
      }
      CheckBox {
        id: terminalCheck; text: "Terminal"; palette.windowText: editor.foreground
        palette.buttonText: editor.foreground; palette.highlight: editor.accent
      }
    }
    Text {
      width: parent.width; wrapMode: Text.WordWrap
      text: editor.confirmDelete ? "Delete this preset? Its open windows will keep running."
        : editor.error || (editor.original.customApps ? "Your custom app commands will be preserved." : "Project terminals ask before activating .venv or venv.")
      textFormat: Text.PlainText
      color: editor.error || editor.confirmDelete ? "#f08880" : editor.foreground
      opacity: editor.error || editor.confirmDelete ? 1 : 0.6
      font.pixelSize: 13
      height: 38
    }
    Row {
      spacing: 10
      ActionButton {
        text: editor.busy ? "Saving…" : "Save preset"; primary: true; accent: editor.accent
        enabled: !editor.busy && nameField.text.trim() !== "" && directoryField.text.trim() !== ""
        onClicked: editor.saveRequested(editor.draft())
      }
      ActionButton { text: "Cancel"; enabled: !editor.busy; foreground: editor.foreground; onClicked: editor.cancelled() }
      ActionButton {
        visible: !!editor.original.originalId
        text: editor.confirmDelete ? "Confirm delete" : "Delete preset"
        foreground: "#f08880"; enabled: !editor.busy
        onClicked: {
          if (editor.confirmDelete) editor.deleteRequested(editor.original)
          else editor.confirmDelete = true
        }
      }
    }
  }

  component Field: Column {
    property string label: ""
    property alias text: input.text
    property string placeholder: ""
    function forceActiveFocus() { input.forceActiveFocus() }
    spacing: 6
    Text { text: parent.label; color: editor.foreground; font.pixelSize: 12; opacity: 0.7 }
    TextField {
      id: input; width: parent.width; height: 38
      placeholderText: parent.placeholder
      color: editor.foreground
      placeholderTextColor: Qt.rgba(editor.foreground.r, editor.foreground.g, editor.foreground.b, 0.35)
      selectionColor: editor.accent
      font.pixelSize: 14
      background: Rectangle {
        radius: 8; color: Qt.rgba(1, 1, 1, 0.055)
        border.width: 1; border.color: input.activeFocus ? editor.accent : Qt.rgba(1, 1, 1, 0.1)
      }
    }
  }
}
