import Foundation

/// What a person sees before they add a shared spot: its title, the uses that it names, what its text seems to do beyond
/// them, what runs by itself and its whole text (Z6). It learns this from the text of the files, runs none of them, and
/// warns without a refusal.
public struct ReviewSpot: Equatable, Sendable {
    /// The ID of its sheet, which has no card in the grid.
    public static let id = "openspot/install"
    static let textLimit = 256_000
    static let installPart = "install"

    public let shared: SharedSpot
    public let name: String
    public let symbol: String
    public let description: String?
    public let folder: URL
    public let subtitle: String
    /// The lines of what it uses, what it can also do and what runs by itself, as the review shows them, or nothing.
    public let trust: String
    /// Each line of what it can also do and of what runs by itself, after the title of its section, such as
    /// `Can also: Delete files with rm`.
    public let canDo: [String]
    private let text: String
    private let canAdd: Bool
    /// The `.spot` file that its Add reads again, and the lock that records it.
    private var source: URL?
    private var lock: SpotLock?

    /// Reads a spot for a plugins folder. Throws a fault when it gives no spot or cannot go into that folder. With `canAdd`
    /// false it only shows the text.
    public init(spot: SharedSpot, folder: URL, canAdd: Bool = true) throws {
        if let clash = spot.clash(in: folder) { throw SpotError.fault(clash) }
        let scan = try Self.scan(of: spot)
        let spots = scan.files.flatMap(\.spots)
        let primary = spot.files.lazy.compactMap { file in spots.first { $0.url.path.hasSuffix("/\(file.path)") } }.first
        guard let primary else { throw SpotError.fault("This file holds no spot.") }
        let runs = Self.selfRuns(in: scan)
        self.shared = spot
        self.canAdd = canAdd
        name = primary.name
        symbol = primary.symbol
        description = primary.subtitle
        self.folder = folder
        let programs = spot.files.filter { ($0.isExecutable || ViewLibrary.isLibrary($0.path)) && !Self.canShow($0) }.map(\.path)
        let quiet = "Runs only when you use it"
        subtitle = !programs.isEmpty ? "Holds a program that you cannot read" : primary.subtitle ?? (runs.isEmpty ? quiet : "Runs by itself")
        let uses = SpotUse.allCases.filter { use in scan.scripts.contains { $0.uses.contains(use) } }
        let present = spot.files.map(\.path).filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }
        let installed = Set(present.flatMap { (try? SpotUse.set(SpotHeader(url: folder.appendingPathComponent($0)).block.value("uses"), of: $0)) ?? [] })
        let grown = spot.replaced(in: folder).isEmpty ? [] : uses.filter { !installed.contains($0) }
        let canAlso = Self.canAlso(spot, uses: Set(uses), id: primary.id)
        canDo = canAlso.map { "Can also: \($0)" } + runs.map { "Runs by itself: \($0)" }
        trust = [
            Self.section("Uses", uses.isEmpty ? [] : [uses.map(\.rawValue).joined(separator: ", ")]),
            Self.section("Can also", canAlso),
            Self.section("Runs by itself", runs)
        ].compactMap { $0 }.joined()
        text = [
            grown.isEmpty ? "\(primary.name)\n\n" : "\(primary.name)\nThis version adds: \(grown.map(\.rawValue).joined(separator: ", "))\n\n",
            programs.isEmpty ? nil : Self.section(
                "Program that Openspot cannot show",
                programs + ["It can do all that you can. Add it only if you trust the sender."]
                    + (programs.contains { Self.hasSource($0, in: spot) } ? ["The source beside it may not match the program."] : [])
            ),
            uses.isEmpty ? "Uses no power\n\n" : Self.section("Uses", [uses.map(\.rawValue).joined(separator: ", ")]),
            Self.section("Can also", canAlso),
            runs.isEmpty ? "\(quiet)\n\n" : Self.section("Runs by itself", runs),
            Self.section("Replaces, and moves the old file to the Trash", spot.replaced(in: folder)),
            Self.section("Will not load", scan.refused.map { "\($0.file): \($0.reason)" })
        ].compactMap { $0 }.joined() + spot.files.map(Self.shown).joined(separator: "\n")
    }

    /// Reads a `.spot` file for a plugins folder, which its Add puts in that folder and records in the lock (N1).
    public init(file: URL, folder: URL, lock: SpotLock) throws {
        try self.init(spot: SharedSpot(contentsOf: file), folder: folder)
        source = file
        self.lock = lock
    }

    /// Adds the spot as `openspot spot add` adds its file, with each file that the review names as replaced, and returns the
    /// toast. A file that changed after the review adds nothing.
    func add() async throws -> String {
        guard canAdd, let source, let lock else { throw SpotError.failed(1, "This sheet cannot do that.") }
        _ = try await lock.add(.file(source), to: folder, isConfirmed: true, replaces: shared.replaced(in: folder), expecting: shared)
        return TextBlock(fields: [.init(key: "toast", value: "\(name) added")]).text
    }

    /// Its sheet, which grows out of the search field.
    public var spot: Spot {
        Spot(id: Self.id, name: name, url: folder, kind: .list, symbol: symbol, subtitle: subtitle, read: .sheet, order: .max, host: .review(self), growsFromField: true)
    }

    /// Answers one call with the text a script would print.
    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            return sheet
        default:
            throw SpotError.failed(1, "This sheet cannot do that.")
        }
    }

    private var sheet: String {
        guard canAdd else { return [TextBlock(fields: [.init(key: "grid", value: "review")]).text, reviewPart.text].joined(separator: "\n") }
        return [
            TextBlock(fields: [.init(key: "grid", value: "review"), .init(key: "grid", value: Self.installPart)]).text,
            reviewPart.text,
            TextBlock(fields: [
                .init(key: "button", value: Self.installPart),
                .init(key: "title", value: "Add"),
                .init(key: "shortcut", value: "cmd+return"),
                .init(key: "close", value: "true"),
                .init(key: "look", value: "strong")
            ]).text
        ].joined(separator: "\n")
    }

    private var reviewPart: TextBlock {
        TextBlock(fields: [
            .init(key: "field", value: "review"),
            .init(key: "readonly", value: "true"),
            .init(key: "value", value: text)
        ])
    }

    /// Reads the spot as a scan would, from a folder that holds only its files.
    private static func scan(of spot: SharedSpot) throws -> ScanResult {
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-review-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: place) }
        try spot.add(to: place)
        return try SpotFolder(url: place).scan()
    }

    /// A line for each script that runs with no act of a person, which says when.
    private static func selfRuns(in scan: ScanResult) -> [String] {
        let placed = Set(scan.files.flatMap(\.spots).flatMap(\.places))
        return scan.scripts.compactMap { script in
            var moments: [String] = switch script.mode {
            case .always: ["keeps running while Openspot runs"]
            case .stay: ["keeps running while it is in use"]
            case .once, .inline: []
            }
            for moment in script.read?.moments ?? [] {
                switch moment {
                case .panel: moments.append("when the panel opens")
                case .every(let seconds): moments.append("every \(Int(seconds)) seconds")
                case .event(let name): moments.append("on \(name)")
                case .sheet: break
                }
            }
            if placed.contains(script.id), script.read?.seconds == nil, script.read?.has(.panel) != true {
                moments.append("when the panel opens")
            }
            return moments.isEmpty ? nil : "\(script.name): \(moments.joined(separator: ", "))"
        }
    }

    /// A line for each thing that the text of the files seems to do and `uses` does not name: the network, a delete, a
    /// screenshot or a copy that skips `openspot`, and each call of `openspot` for another use.
    private static func canAlso(_ spot: SharedSpot, uses: Set<SpotUse>, id: String) -> [String] {
        let texts = spot.files.compactMap(\.text)
        func found(_ tools: [String]) -> [String] {
            tools.filter { tool in
                let word = try? NSRegularExpression(pattern: "(?<![\\w./-])\(tool)(?![\\w-])")
                return texts.contains { word?.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
            }
        }
        var lines: [String] = []
        let network = found(["curl", "wget", "nc"])
        if !network.isEmpty, !uses.contains(.network) { lines.append("Reach the network with \(listed(network))") }
        if !found(["rm"]).isEmpty { lines.append("Delete files with rm") }
        if !found(["screencapture"]).isEmpty { lines.append("Take screenshots with screencapture in place of openspot screen") }
        if !found(["pbcopy"]).isEmpty { lines.append("Copy with pbcopy in place of openspot clipboard") }
        if !found(["pbpaste"]).isEmpty { lines.append("Read the clipboard with pbpaste in place of openspot clipboard") }
        for arguments in texts.flatMap(calls) {
            guard let power = SpotPower(arguments: arguments, of: id), !uses.contains(power.use) else { continue }
            let line = "Call openspot \(arguments[0]) \(arguments[1]) without uses=\(power.use.rawValue)"
            if !lines.contains(line) { lines.append(line) }
        }
        return lines
    }

    /// The words of each call of `openspot` in a text: a command in a shell, or `openspot.call([...])` in JavaScript.
    private static func calls(in text: String) -> [[String]] {
        let shell = text.matches(of: /openspot[ \t]+([a-z]+)[ \t]+([a-z-]+)((?:[ \t]+[^\s;|&)]+)*)/).map { match in
            [String(match.1), String(match.2)] + match.3.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(unquoted)
        }
        let inline = text.matches(of: /openspot\.call\(\s*\[([^\]]*)\]/).map { match in
            match.1.split(separator: ",").map(unquoted)
        }
        return shell + inline
    }

    private static func unquoted(_ word: Substring) -> String {
        word.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'"))
    }

    /// Words joined as a list is read: `a`, `a and b`, `a, b and c`.
    private static func listed(_ words: [String]) -> String {
        words.count < 2 ? words.joined() : "\(words.dropLast().joined(separator: ", ")) and \(words.last ?? "")"
    }

    private static func section(_ title: String, _ lines: [String]) -> String? {
        lines.isEmpty ? nil : "\(title)\n\(lines.joined(separator: "\n"))\n\n"
    }

    /// Whether this path is the program of a Swift script or the library of a view in the spot.
    private static func hasSource(_ path: String, in spot: SharedSpot) -> Bool {
        spot.files.contains { SwiftProgram.path(beside: $0.path) == path || (URL(fileURLWithPath: $0.path).pathExtension == SwiftProgram.sourceExtension && ViewLibrary.path(beside: $0.path) == path) }
    }

    private static func canShow(_ file: SharedSpot.File) -> Bool {
        file.text != nil && file.contents.count <= textLimit
    }

    private static func shown(_ file: SharedSpot.File) -> String {
        if canShow(file), let text = file.text { return "\(file.path)\n\(text)" }
        let reason = file.text == nil ? "Not text, so Openspot cannot show it." : "Too long to show."
        return "\(file.path)\n\(reason) \(file.contents.count) bytes.\n"
    }
}
