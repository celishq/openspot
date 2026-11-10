import AppKit
import OpenspotCore

/// The log of what the pointer and the keys do while a recording runs, one JSON object on each line (S5). A listen-only
/// event tap on its own thread writes it. Keys need Input Monitoring: without it, this asks macOS for it and logs the
/// pointer alone (S6).
final class SpotEventLog: @unchecked Sendable {
    private static let pointer: [CGEventType] = [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown, .otherMouseUp
    ]
    private static let keyNames: [Int64: String] = [
        36: "return", 48: "tab", 49: "space", 51: "delete", 53: "escape", 117: "forward delete",
        123: "left", 124: "right", 125: "down", 126: "up", 115: "home", 119: "end", 116: "page up", 121: "page down"
    ]

    private let handle: FileHandle
    private let frame: CGRect
    private let start = ProcessInfo.processInfo.systemUptime
    private var tap: CFMachPort?
    private var loop: CFRunLoop?
    private let ended = DispatchSemaphore(value: 0)

    /// Opens the log and writes its first line: the size of the video in points and its pixels for each point.
    init(path: String, frame: CGRect, scale: CGFloat) throws {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard FileManager.default.createFile(atPath: path, contents: nil), let handle = FileHandle(forWritingAtPath: path) else {
            throw PluginError.fault("Openspot cannot write the events to \(path). Name a file in a folder that you can write to.")
        }
        self.handle = handle
        self.frame = frame
        write(["type": "frame", "width": Double(frame.width), "height": Double(frame.height), "scale": Double(scale)])
    }

    /// Starts the tap on its own thread, and returns once it listens.
    func listen() throws {
        let keys = CGPreflightListenEventAccess() || CGRequestListenEventAccess()
        let types = Self.pointer + (keys ? [.keyDown] : [])
        let mask = types.reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, info in
            if let info { Unmanaged<SpotEventLog>.fromOpaque(info).takeUnretainedValue().note(type, event) }
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            throw PluginError.fault("Openspot cannot follow the pointer for the events. Record again without `--events`.")
        }
        self.tap = tap
        let ready = DispatchSemaphore(value: 0)
        let thread = Thread { [self] in
            loop = CFRunLoopGetCurrent()
            guard let tap = self.tap else { ready.signal(); return }
            CFRunLoopAddSource(loop, CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            ready.signal()
            CFRunLoopRun()
            try? handle.close()
            ended.signal()
        }
        thread.start()
        ready.wait()
    }

    /// Stops the tap, and returns once the log is closed.
    func stop() {
        guard let tap, let loop else {
            try? handle.close()
            return
        }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopStop(loop)
        ended.wait()
    }

    private func note(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            tap.map { CGEvent.tapEnable(tap: $0, enable: true) }
            return
        }
        let time = (Double(event.timestamp) / 1_000_000_000 - start) * 1000
        var line: [String: Any] = ["t": time.rounded() / 1000]
        if type == .keyDown {
            line["type"] = "key"
            line["key"] = Self.key(of: event)
            line["modifiers"] = Self.modifiers(of: event.flags)
        } else {
            line["x"] = ((event.location.x - frame.minX) * 2).rounded() / 2
            line["y"] = ((event.location.y - frame.minY) * 2).rounded() / 2
            switch type {
            case .leftMouseDown, .rightMouseDown, .otherMouseDown: line["type"] = "down"
            case .leftMouseUp, .rightMouseUp, .otherMouseUp: line["type"] = "up"
            default: line["type"] = "move"
            }
            if line["type"] as? String != "move" { line["button"] = Self.button(of: type) }
        }
        write(line)
    }

    private func write(_ line: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: line, options: [.sortedKeys]) else { return }
        try? handle.write(contentsOf: data + Data("\n".utf8))
    }

    private static func key(of event: CGEvent) -> String {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        if let name = keyNames[code] { return name }
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        event.keyboardGetUnicodeString(maxStringLength: characters.count, actualStringLength: &length, unicodeString: &characters)
        return String(utf16CodeUnits: characters, count: length).lowercased()
    }

    private static func modifiers(of flags: CGEventFlags) -> [String] {
        [(CGEventFlags.maskCommand, "cmd"), (.maskShift, "shift"), (.maskAlternate, "option"), (.maskControl, "control")]
            .filter { flags.contains($0.0) }.map(\.1)
    }

    private static func button(of type: CGEventType) -> String {
        switch type {
        case .leftMouseDown, .leftMouseUp: "left"
        case .rightMouseDown, .rightMouseUp: "right"
        default: "other"
        }
    }
}
