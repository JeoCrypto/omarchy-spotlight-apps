// Runs PasteGuard through the cases that matter and prints one line per case:
//   CASE <name> PASS|FAIL <details>
// Started by tests/test_paste_guard.py with PasteGuard.qml and BoundedRun.qml
// copied next to it. The clipboard read is replaced by a slow stand-in, so the
// field can change while the read is still running.
import QtQuick
import Quickshell

ShellRoot {
  id: root

  property int index: -1
  // `during` runs while the read is in progress; `expect` is the field's text
  // once the read has ended.
  property var cases: [
    { name: "paste-arrives", before: "ab", during: () => {}, expect: "abLATE" },
    { name: "dropped-after-edit", before: "ab", during: () => { field.text = "abc" }, expect: "abc" },
    { name: "dropped-after-clear-and-refill", before: "ab",
      during: () => { field.text = ""; field.text = "ab" }, expect: "ab" },
    { name: "dropped-after-form-change", before: "ab", during: () => { guard.invalidate() }, expect: "ab" },
    { name: "dropped-when-hidden", before: "ab", during: () => { field.visible = false }, expect: "ab" },
    { name: "second-paste-is-ignored", before: "ab", during: () => { guard.request() }, expect: "abLATE" }
  ]

  function next() {
    index += 1
    if (index >= cases.length) { console.log("DONE"); Qt.quit(); return }
    const t = cases[index]
    field.visible = true
    field.text = t.before
    field.cursorPosition = t.before.length
    guard.request()
    during.restart()
    verdict.restart()
  }

  Item {
    TextInput {
      id: field
      PasteGuard {
        id: guard
        field: field
        command: ["sh", "-c", "sleep 0.4; printf LATE"]
      }
    }
  }

  Timer { id: during; interval: 150; onTriggered: root.cases[root.index].during() }
  Timer {
    id: verdict
    interval: 1200
    onTriggered: {
      const t = root.cases[root.index]
      console.log("CASE " + t.name + " " + (field.text === t.expect ? "PASS" : "FAIL") +
        " text=" + JSON.stringify(field.text) + " expected=" + JSON.stringify(t.expect))
      root.next()
    }
  }
  Timer { interval: 100; running: true; onTriggered: root.next() }
  Timer { interval: 30000; running: true; onTriggered: { console.log("CASE suite FAIL timed out at " + root.index); Qt.quit() } }
}
