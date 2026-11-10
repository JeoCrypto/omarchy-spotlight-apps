import QtQuick

// Placed inside a text input. Qt's own paste reads the whole clipboard on the
// interface thread with no size or time limit, so this takes over every way
// of pasting: the paste shortcuts, middle-click and the context menu. Paste
// still works, through a separate one-second, 2 KB read of plain text, of
// which the first line is inserted.
//
// The input must call handleKey() first in its Keys.onPressed handler.
Item {
  id: guard

  required property var field
  property int maxChars: 512
  signal inserted()

  anchors.fill: parent

  function handleKey(event) {
    const shiftInsert = event.key === Qt.Key_Insert && (event.modifiers & Qt.ShiftModifier)
    if (event.matches(StandardKey.Paste) || shiftInsert) { paste.start(); return true }
    return event.key === Qt.Key_Menu
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.IBeamCursor
  }

  BoundedRun {
    id: paste
    argv: ["wl-paste", "--no-newline", "--type", "text/plain"]
    seconds: 1
    maxBytes: 2048
    onFinished: function(exitCode, output, errors) {
      const text = String(output || "").split("\n")[0].replace(/[\u0000-\u001f\u007f�]/g, "").slice(0, guard.maxChars)
      if (!text || !guard.field) return
      guard.field.insert(guard.field.cursorPosition, text)
      guard.inserted()
    }
  }
}
