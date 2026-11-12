import Foundation

/// What the playground shows: the text of a sheet, the sheet it draws, its faults, what a person did to it and the newest
/// calls of its spot. A sheet that cannot be drawn leaves the last one in place, so that typing does not make it flicker.
public struct SheetSandbox: Equatable, Sendable {
    public private(set) var text = ""
    public private(set) var panel: SheetParts?
    public private(set) var faults: [String] = []
    public private(set) var log: [String] = []
    /// The newest calls first.
    public private(set) var calls: [PlaygroundCall] = []

    private static let logLength = 8
    private static let callLength = 20

    public init() {}

    /// The command that the sandbox calls for a file: it reads a file with an `on`, and clicks any other.
    public static func command(file: URL) -> Spot {
        let header = SpotHeader(url: file).block
        return Spot(
            id: file.lastPathComponent,
            name: file.lastPathComponent,
            url: file,
            kind: .list,
            read: (try? SpotRead(on: header.values("on"), of: file.lastPathComponent)) ?? nil,
            mode: header.value("mode").flatMap(SpotMode.init(rawValue:)).map { $0.stays ? .stay : .once } ?? .once
        )
    }

    /// Reads a sheet that a person typed or a script printed.
    public mutating func take(text: String) {
        self.text = text
        let output = SpotOutput(text: text)
        faults = text.isEmpty ? [] : output.sheetFaults
        if let panel = SheetParts(output: output) { self.panel = panel }
    }

    /// Takes a value that a person set in the sheet, and returns the generation of the call that reports it.
    @discardableResult
    public mutating func set(_ value: String, of id: String) -> Int {
        record("\(id) \(value)")
        return panel?.set(value, of: id) ?? 0
    }

    /// Takes a press in the sheet, and returns the generation of the call that reports it.
    @discardableResult
    public mutating func press(_ id: String) -> Int {
        record(id)
        return panel?.advance() ?? 0
    }

    /// Shows a frame that a script printed, which its sheet draws.
    public mutating func note(frame text: String) {
        self.text = text
        let output = SpotOutput(text: text)
        guard !output.parts.isEmpty else { return }
        faults = output.layout == nil ? output.partFaults : output.sheetFaults
    }

    public mutating func record(_ line: String) {
        log = Array((log + [line]).suffix(Self.logLength))
    }

    public mutating func take(call: PlaygroundCall) {
        calls = Array(([call] + calls).prefix(Self.callLength))
    }

    /// The spots to start from: each runnable example of the guide, by its title, then each sheet example as a spot that
    /// prints it when its sheet opens.
    public static func presets(guide: String) -> [(name: String, text: String)] {
        let fences = ["```sh\n", "```js\n"]
        var examples: [(name: String, text: String)] = []
        var rest = guide[...]
        while let start = fences.compactMap({ rest.range(of: $0) }).min(by: { $0.lowerBound < $1.lowerBound }) {
            rest = rest[start.upperBound...]
            guard let end = rest.range(of: "```") else { break }
            let text = String(rest[..<end.lowerBound])
            rest = rest[end.upperBound...]
            if let name = SpotHeader(text: text).block.value("title") { examples.append((name, text)) }
        }
        return examples + SheetExamples.all.map { ($0.name, "#!/bin/sh\n# title=\($0.name)\n# on=sheet.open\ncat <<'SHEET'\n\($0.text)\nSHEET\n") }
    }

    /// The file that the playground runs and its ID. A named file runs in place, with the ID that its spots folder gives
    /// it, or its name with no extension outside one. Typed text runs from a copy in the scratch folder, as `playground`.
    public static func place(of file: URL?, text: String, plugins: URL, scratch: URL) -> (url: URL, id: String) {
        guard let file else { return (scratch.appendingPathComponent("playground.\(fileExtension(of: text))"), "playground") }
        let folder = file.deletingLastPathComponent().resolvingSymlinksInPath()
        if folder.pathExtension == SpotFolder.spotExtension, folder.deletingLastPathComponent().path == plugins.resolvingSymlinksInPath().path {
            return (file, SpotFolder.id(of: file))
        }
        return (file, file.deletingPathExtension().lastPathComponent)
    }

    /// The extension of the file that runs a typed spot: `js` for a header in `//` lines, and else `sh`.
    public static func fileExtension(of text: String) -> String {
        text.hasPrefix("//") ? SpotFile.inlineExtension : "sh"
    }
}
