#!/usr/bin/env swift

// Openspot builds this file with the Swift files of `grid/`, and keeps one process while the panel shows, so a press
// shows the grid at once. The call of a press stays open until the person picks a block or hides the grid, and the
// pick moves the front window with `openspot window move`. A move that Accessibility refuses opens its settings.
import AppKit

let grid = Grid()
var shown: String?

/// Moves the front window to the block, then ends the call. Without Accessibility it opens the settings page that the
/// move names, and shows no failure.
func move(to pick: Pick, call: String) {
    let move = Process()
    let output = Pipe()
    move.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    move.arguments = ["openspot", "window", "move", pick.text]
    move.standardInput = FileHandle.nullDevice
    move.standardOutput = output
    move.standardError = output
    move.terminationHandler = { done in
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        DispatchQueue.main.async { moved(status: done.terminationStatus, text: text, call: call) }
    }
    do { try move.run() } catch { moved(status: 1, text: "", call: call) }
}

func moved(status: Int32, text: String, call: String) {
    grid.land()
    let lines = text.split(separator: "\n").map(String.init)
    guard status != 0 else { return Link.end(call) }
    guard let link = lines.first(where: { $0.hasPrefix("link=") }).map({ String($0.dropFirst(5)) }) else {
        Link.frame("toast=\(Link.value(lines.last ?? "Openspot cannot move the window."))")
        return Link.end(call)
    }
    let open = Process()
    open.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    open.arguments = ["open", link]
    open.standardInput = FileHandle.nullDevice
    open.terminationHandler = { _ in DispatchQueue.main.async { Link.end(call) } }
    do { try open.run() } catch { Link.end(call) }
}

/// Answers `pick` and `frames` with the math of the grid and quits, so a test reaches it with no window.
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.first == "frames" {
    let numbers = arguments.dropFirst().compactMap { Double($0) }
    guard numbers.count == 6, numbers[0] > 0, numbers[1] > 0 else {
        FileHandle.standardError.write(Data("Use: grid frames <columns> <rows> <x> <y> <width> <height>\n".utf8))
        exit(2)
    }
    let columns = Int(numbers[0]), rows = Int(numbers[1])
    let area = CGRect(x: numbers[2], y: numbers[3], width: numbers[4], height: numbers[5])
    var lines: [String] = []
    for first in 0..<columns * rows {
        for last in first..<columns * rows {
            let pick = Pick(columns: columns, rows: rows, from: (first % columns, first / columns), to: (last % columns, last / columns))
            let frame = pick.frame(in: area)
            lines.append("\(pick.text)|\([frame.minX, frame.minY, frame.width, frame.height].map { String(Int($0)) }.joined(separator: " "))")
        }
    }
    print(lines.joined(separator: "\n"))
    exit(0)
}
if arguments.first == "pick" {
    let numbers = arguments.dropFirst().compactMap { Int($0) }
    guard numbers.count == 6, numbers[0] > 0, numbers[1] > 0 else {
        FileHandle.standardError.write(Data("Use: grid pick <columns> <rows> <column> <row> <column> <row>\n".utf8))
        exit(2)
    }
    print(Pick(columns: numbers[0], rows: numbers[1], from: (numbers[2], numbers[3]), to: (numbers[4], numbers[5])).text)
    exit(0)
}

Link.listen { call in
    Link.start(call.id)
    switch call.arguments.first {
    case "read":
        if !(call.variables["OPENSPOT_REASON"] ?? "").isEmpty { grid.warm() }
        Link.end(call.id)
    case "open":
        guard shown == nil else { return Link.end(call.id) }
        shown = call.id
        grid.show { pick in
            shown = nil
            guard let pick else { return Link.end(call.id) }
            move(to: pick, call: call.id)
        }
    default: Link.end(call.id)
    }
} stop: { id in
    if id == shown { grid.hide() }
} end: {
    exit(0)
}
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
