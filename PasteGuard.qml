import QtQuick

// Placed inside a text input. Qt's own paste reads the whole clipboard on the
// interface thread with no size or time limit, so this takes over every way
// of pasting: the paste shortcuts, middle-click and the context menu. Paste
// still works, through a separate one-second, 2 KB read of plain text, of
// which the first line is inserted.
//
// The read takes a moment, so its result is used only if the field is still
// as it was when the paste was asked for. Text that was edited, cleared or
// filled in again meanwhile, a field that lost the focus or was hidden, or a
// call to invalidate() all drop the pending paste. A second paste while one
// is being read is ignored.
//
// The input must call handleKey() first in its Keys.onPressed handler.
Item {
  id: guard

  required property var field
  property int maxChars: 512
  signal inserted()

  anchors.fill: parent

  // What is run to read the clipboard.
  property var command: ["wl-paste", "--no-newline", "--type", "text/plain"]

  // Goes up whenever a pending paste stops being wanted.
  property int epoch: 0
  property int askedAt: -1
  function invalidate() { epoch += 1 }
  function request() {
    if (paste.running) return
    askedAt = epoch
    paste.start(command)
  }

  onVisibleChanged: if (!visible) invalidate()
  Connections {
    target: guard.field
    function onTextChanged() { guard.invalidate() }
    function onActiveFocusChanged() { if (!guard.field.activeFocus) guard.invalidate() }
  }

  function handleKey(event) {
    const shiftInsert = event.key === Qt.Key_Insert && (event.modifiers & Qt.ShiftModifier)
    if (event.matches(StandardKey.Paste) || shiftInsert) { request(); return true }
    return event.key === Qt.Key_Menu
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.IBeamCursor
  }

  BoundedRun {
    id: paste
    seconds: 1
    maxBytes: 2048
    onFinished: function(exitCode, output, errors) {
      if (guard.askedAt !== guard.epoch || !guard.field) return
      const text = String(output || "").split("\n")[0].replace(/[\u0000-\u001f\u007f\ufffd]/g, "").slice(0, guard.maxChars)
      if (!text) return
      guard.field.insert(guard.field.cursorPosition, text)
      guard.inserted()
    }
  }
}
