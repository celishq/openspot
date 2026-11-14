import Foundation

public struct SheetSandbox: Equatable, Sendable {
    public private(set) var text = ""
    public private(set) var panel: SheetParts?
    public private(set) var faults: [String] = []
    public private(set) var log: [String] = []
    public private(set) var calls: [PlaygroundCall] = []

    private static let logLength = 8
    private static let callLength = 20

    public init() {}

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

    public mutating func take(text: String) {
        self.text = text
        let output = SpotOutput(text: text)
        faults = text.isEmpty ? [] : output.sheetFaults
        if let panel = SheetParts(output: output) { self.panel = panel }
    }

    @discardableResult
    public mutating func set(_ value: String, of id: String) -> Int {
        record("\(id) \(value)")
        return panel?.set(value, of: id) ?? 0
    }

    @discardableResult
    public mutating func press(_ id: String) -> Int {
        record(id)
        return panel?.advance() ?? 0
    }

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

    public static func place(of file: URL?, text: String, spots: URL, scratch: URL) -> (url: URL, id: String) {
        guard let file else { return (scratch.appendingPathComponent("playground.\(fileExtension(of: text))"), "playground") }
        let folder = file.deletingLastPathComponent().resolvingSymlinksInPath()
        if folder.pathExtension == SpotPackage.fileExtension, folder.deletingLastPathComponent().path == spots.resolvingSymlinksInPath().path {
            return (file, SpotID(file: file).description)
        }
        return (file, file.deletingPathExtension().lastPathComponent)
    }

    public static func fileExtension(of text: String) -> String {
        text.hasPrefix("//") ? SpotFile.inlineExtension : "sh"
    }
}
