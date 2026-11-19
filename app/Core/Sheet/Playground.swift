import Foundation

public struct Playground: Equatable, Sendable {
    public private(set) var text = ""
    public private(set) var panel: SheetParts?
    public private(set) var faults: [String] = []
    public private(set) var log: [String] = []
    public private(set) var calls: [PlaygroundCall] = []

    private static let logLength = 8
    private static let callLength = 20

    public init() {}

    public static func command(file: URL) -> Spot {
        let manifest = (try? Manifest(beside: file).script(file)) ?? Manifest(text: nil, folder: "")
        return Spot(
            id: file.lastPathComponent,
            name: file.lastPathComponent,
            url: file,
            kind: .list,
            on: (try? ShowEvents(on: manifest.on, of: file.lastPathComponent)) ?? nil,
            mode: manifest.mode.flatMap(SpotMode.init(rawValue:)).map { $0.stays ? .stay : .once } ?? .once
        )
    }

    public mutating func take(text: String) {
        self.text = text
        let check = FrameCheck(text: text)
        faults = text.isEmpty ? [] : check.sheetFaults
        if let panel = SheetParts(output: check.output) { self.panel = panel }
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
        let check = FrameCheck(text: text)
        guard !check.output.parts.isEmpty else { return }
        faults = check.output.layout == nil ? check.partFaults : check.sheetFaults
    }

    public mutating func record(_ line: String) {
        log = Array((log + [line]).suffix(Self.logLength))
    }

    public mutating func take(call: PlaygroundCall) {
        calls = Array(([call] + calls).prefix(Self.callLength))
    }

    public static func presets(guide: String) -> [(name: String, manifest: String, text: String)] {
        var examples: [(name: String, manifest: String, text: String)] = []
        var fence: (language: String, lines: [String])?
        var manifest: String?
        for line in guide.components(separatedBy: "\n") {
            guard let open = fence else {
                if line.hasPrefix("```") { fence = (String(line.dropFirst(3)), []) }
                continue
            }
            guard line == "```" else {
                fence?.lines.append(line)
                continue
            }
            let text = open.lines.map { $0 + "\n" }.joined()
            fence = nil
            if open.language == "toml" {
                manifest = text
                continue
            }
            defer { manifest = nil }
            guard ["sh", "js"].contains(open.language), let manifest,
                  case .string(let name) = (try? ConfigDocument(text: manifest))?.values["title"] else { continue }
            examples.append((name, manifest, text))
        }
        return examples + SheetExamples.all.map { example in
            var manifest = ConfigDocument()
            manifest.set("title", to: .string(example.name))
            manifest.set("on", to: .strings(["sheet.open"]))
            return (example.name, manifest.text, "#!/bin/sh\ncat <<'SHEET'\n\(example.text)\nSHEET\n")
        }
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
        text.hasPrefix("#!") ? "sh" : SpotFile.inlineExtension
    }
}
