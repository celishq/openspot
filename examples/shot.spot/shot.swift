#!/usr/bin/env swift

// Openspot builds this file with the Swift files of `shot/`. A press takes a picture with `openspot screen shot`, and
// its call stays open while the editor shows. Closing the editor copies the picture and ends the call; a second press of
// the card brings the editor to the front.
import AppKit

var editor: Editor?
var editing: String?

/// Runs `openspot` with these words, and hands back its status, its output and the last line of its errors.
func openspot(_ words: [String], then: @escaping (Int32, String, String) -> Void) {
    let process = Process()
    let output = Pipe()
    let errors = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["openspot"] + words
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output
    process.standardError = errors
    process.terminationHandler = { done in
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let fault = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let last = fault.split(separator: "\n").last.map(String.init) ?? ""
        DispatchQueue.main.async { then(done.terminationStatus, text, last) }
    }
    do { try process.run() } catch { then(1, "", "Openspot cannot run `openspot`.") }
}

/// Shows a toast, then ends a call.
func end(_ call: String, saying text: String) {
    guard !text.isEmpty else { return Link.end(call) }
    openspot(["toast", text]) { _, _, _ in Link.end(call) }
}

/// Takes a picture and opens it in the editor, or ends the call when the person takes none or the call stopped.
func shoot(_ call: String) {
    editing = call
    openspot(["screen", "shot"]) { status, text, fault in
        guard editing == call else { return Link.end(call) }
        guard status == 0 else {
            editing = nil
            return end(call, saying: fault)
        }
        let path = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            editing = nil
            return Link.end(call)
        }
        let file = URL(fileURLWithPath: path)
        guard let picture = NSImage(contentsOf: file) else {
            editing = nil
            return end(call, saying: "Openspot cannot open \(file.lastPathComponent) to mark it.")
        }
        editor = Editor(picture: picture, file: file) {
            editor = nil
            editing = nil
            openspot(["clipboard", "copy", file.path]) { status, _, fault in
                end(call, saying: status == 0 ? "Copied the picture." : fault)
            }
        }
    }
}

Link.listen { call in
    Link.start(call.id)
    switch call.arguments.first {
    case "shoot":
        guard editing == nil else {
            editor?.front()
            return Link.end(call.id)
        }
        shoot(call.id)
    default: Link.end(call.id)
    }
} stop: { id in
    guard id == editing else { return }
    if let editor {
        // A frame for the call within two seconds keeps it open, so the editor and its marks stay.
        Link.start(id)
        return editor.front()
    }
    editing = nil
    Link.end(id)
} end: {
    exit(0)
}
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
