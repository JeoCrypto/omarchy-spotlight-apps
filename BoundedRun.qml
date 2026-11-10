import QtQuick
import Quickshell
import Quickshell.Io

// One helper run that always ends: a time limit on the whole command, a cap
// on how much output is kept, and a second deadline here in case the wrapper
// itself stalls. `timeout` stops the command's whole process group, so nothing
// it started is left behind. Only one run at a time; start() returns false
// while one is in progress.
Scope {
  id: run

  property var argv: []
  property int seconds: 10
  property int maxBytes: 262144
  // Sent to the command's standard input when not empty.
  property string input: ""
  readonly property bool running: proc.running

  signal finished(int exitCode, string output, string errors)

  function start(args) {
    if (proc.running) return false
    if (args !== undefined) argv = args
    proc.command = ["bash", "-c",
      'set -o pipefail; limit=$1; bytes=$2; shift 2; timeout -k 1 "$limit" "$@" 2> >(head -c 4096 >&2) | head -c "$bytes"',
      "bash", String(seconds), String(maxBytes)].concat(argv)
    proc.running = true
    deadline.restart()
    return true
  }

  Process {
    id: proc
    stdinEnabled: run.input.length > 0
    onStarted: if (run.input.length > 0) write(run.input)
    stdout: StdioCollector { id: out; waitForEnd: true }
    stderr: StdioCollector { id: err; waitForEnd: true }
    onExited: function(exitCode) {
      deadline.stop()
      run.finished(exitCode, out.text, err.text)
    }
  }

  Timer {
    id: deadline
    interval: (run.seconds + 3) * 1000
    onTriggered: if (proc.running) proc.signal(9)
  }
}
