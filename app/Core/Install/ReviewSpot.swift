import Foundation

public struct ReviewSpot: Equatable, Sendable {
    public static let id = "openspot/install"
    static let textLimit = 256_000
    static let installPart = "install"
    static let stopPart = "stop"

    public let shared: SpotPackage
    public let name: String
    public let symbol: String
    public let description: String?
    public let folder: URL
    public let subtitle: String
    public let trust: String
    public let canDo: [String]
    private let text: String
    private let canAdd: Bool
    private var source: URL?
    private var lock: SpotLock?
    private var install: SpotInstall?
    private var clashes = false

    public init(spot: SpotPackage, folder: URL, core: URL? = nil, canAdd: Bool = true) throws {
        if let clash = spot.clash(in: folder) { throw SpotError.fault(clash) }
        let logs = try spot.roots.map { try spot.releaseLog(in: $0) }
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
        let release = (logs.first.flatMap { $0 } ?? ReleaseLog(releases: [])).review(over: spot.roots.first.flatMap { ReleaseLog(installed: $0, in: folder) })
        subtitle = release.isOtherKey ? Self.otherKeySubtitle
            : !programs.isEmpty ? "Holds a program that you cannot read" : primary.subtitle ?? (runs.isEmpty ? quiet : "Runs by itself")
        let uses = SpotUse.allCases.filter { use in scan.scripts.contains { $0.uses.contains(use) } }
        let present = spot.files.map(\.path).filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }
        let installed = Set(present.flatMap { (try? SpotUse.set(Manifest(beside: folder.appendingPathComponent($0)).script($0).uses, of: $0)) ?? [] })
        let grown = spot.replaced(in: folder).isEmpty ? [] : uses.filter { !installed.contains($0) }
        let canAlso = Self.canAlso(spot, uses: Set(uses), id: primary.id)
        let bindings = Self.bindings(in: scan, folder: folder, core: core)
        let readme = spot.readme
        let rows = spot.sampleText.map { Frame(text: $0, kinds: primary.kinds).items.map(\.title) } ?? []
        canDo = canAlso.map { "Can also: \($0)" } + runs.map { "Runs by itself: \($0)" } + bindings.map { "Binds \($0.binding.line)" }
        trust = [
            Self.section("Uses", uses.isEmpty ? [] : [uses.map(\.rawValue).joined(separator: ", ")]),
            Self.section("Binds", bindings.map(\.shown)),
            Self.section("Can also", canAlso),
            Self.section("Runs by itself", runs)
        ].compactMap { $0 }.joined()
        text = [
            ([primary.name] + release.lines + (grown.isEmpty ? [] : ["This version adds: \(grown.map(\.rawValue).joined(separator: ", "))"])).joined(separator: "\n") + "\n\n",
            programs.isEmpty ? nil : Self.section(
                "Program that Openspot cannot show",
                programs + ["It can do all that you can. Add it only if you trust the sender."]
                    + (programs.contains(where: SpotFiles(package: spot).isBuilt) ? ["The source beside it may not match the program."] : [])
            ),
            uses.isEmpty ? "Uses nothing\n\n" : Self.section("Uses", [uses.map(\.rawValue).joined(separator: ", ")]),
            Self.section("Binds", bindings.map(\.shown)),
            Self.section("Can also", canAlso),
            runs.isEmpty ? "\(quiet)\n\n" : Self.section("Runs by itself", runs),
            Self.section("Replaces, and moves the old file to the Trash", spot.replaced(in: folder)),
            Self.section("Changes what other spots call", BoundChange.lines(of: scan.scripts, in: folder)),
            Self.section("Will not load", scan.refused.map { "\($0.file): \($0.reason)" }),
            readme.map { "\(SpotReadme.shown($0))\n\n" },
            Self.section("Preview", rows)
        ].compactMap { $0 }.joined() + spot.files.filter { !$0.path.hasSuffix("/\(ReleaseLog.fileName)") }.map(Self.shown).joined(separator: "\n")
    }

    public init(file: URL, folder: URL, lock: SpotLock) throws {
        try self.init(spot: SpotPackage(contentsOf: file), folder: folder, core: SpotsFolder.core(environment: lock.environment))
        source = file
        self.lock = lock
    }

    init(installing install: SpotInstall) throws {
        try self.init(spot: SpotPackage(paths: [install.source.lastPathComponent], in: install.source.deletingLastPathComponent()), folder: install.spots, core: install.core)
        self.install = install
        clashes = install.clashes()
    }

    public var summary: String {
        "\(name)\n\n\(trust)" + (Self.section("Files", shared.files.map(\.path).filter { !$0.hasSuffix("/\(ReleaseLog.fileName)") }) ?? "")
    }

    func press(_ part: String) async throws -> HostAnswer {
        switch part {
        case Self.installPart: return try await add()
        case Self.stopPart: return HostAnswer(frame: "")
        default:
            guard let install, let clash = SpotClash(rawValue: part) else { throw SpotError.failed(1, "This sheet cannot do that.") }
            return try await Self.installed(install, clash)
        }
    }

    private static func installed(_ install: SpotInstall, _ clash: SpotClash?) async throws -> HostAnswer {
        let said = try await install.run(clash, isConfirmed: true)
        return HostAnswer(frame: "", effects: [.toast(ToastNote(words: said.trimmingCharacters(in: .newlines)))])
    }

    func add() async throws -> HostAnswer {
        if let install { return try await Self.installed(install, nil) }
        guard canAdd, let source, let lock else { throw SpotError.failed(1, "This sheet cannot do that.") }
        _ = try await lock.add(.file(source), to: folder, isConfirmed: true, replaces: shared.replaced(in: folder), expecting: shared)
        return HostAnswer(frame: "", effects: [.toast("\(name) added")])
    }

    public var spot: Spot {
        Spot(id: Self.id, name: name, url: folder, kind: .list, symbol: symbol, subtitle: subtitle, triggers: .sheet, order: .max, host: .review(self), growsFromField: true)
    }

    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "show":
            return sheet
        default:
            throw SpotError.failed(1, "This sheet cannot do that.")
        }
    }

    private var sheet: String {
        let root = RootKey.block([.init(key: "class", value: "gap-group")]).text
        guard canAdd else { return [root, reviewPart.text].joined(separator: "\n") }
        if clashes { return ([root, reviewPart.text] + clashParts.map(\.text)).joined(separator: "\n") }
        return [
            root,
            reviewPart.text,
            TextBlock(fields: [
                .init(key: "button", value: Self.installPart),
                .init(key: "title", value: install == nil ? "Add" : "Install"),
                .init(key: "shortcut", value: "cmd+return"),
                .init(key: "class", value: "bg-accent")
            ]).text
        ].joined(separator: "\n")
    }

    private var clashParts: [TextBlock] {
        let row = "choices"
        func button(_ id: String, _ title: String, _ more: [TextBlock.Field]) -> TextBlock {
            TextBlock(fields: [.init(key: "button", value: id), .init(key: "title", value: title), .init(key: "parent", value: row)] + more)
        }
        return [
            TextBlock(fields: [.init(key: "text", value: "clash"), .init(key: "title", value: "A spot named “\(name)” already exists in your spots. Do you want to replace it with the one you’re installing?")]),
            TextBlock(fields: [.init(key: "box", value: row), .init(key: "class", value: "grid grid-cols-3 gap-part")]),
            button(SpotClash.keepBoth.rawValue, "Keep Both", []),
            button(Self.stopPart, "Stop", [.init(key: "shortcut", value: "escape")]),
            button(SpotClash.replace.rawValue, "Replace", [.init(key: "shortcut", value: "cmd+return"), .init(key: "class", value: "bg-accent")])
        ]
    }

    private var reviewPart: TextBlock {
        TextBlock(fields: [
            .init(key: "field", value: "review"),
            .init(key: "type", value: "multiline"),
            .init(key: "class", value: "grow"),
            .init(key: "readonly", value: "true"),
            .init(key: "value", value: text)
        ])
    }

    private static func scan(of spot: SpotPackage) throws -> ScanResult {
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-review-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: place) }
        try spot.add(to: place)
        return try SpotsFolder(url: place).scan()
    }

    static let otherKeySubtitle = "Signed by another key"

    private static func selfRuns(in scan: ScanResult) -> [String] {
        return scan.scripts.compactMap { script in
            var moments: [String] = switch script.mode {
            case .stay: [script.showsAtLaunch ? "keeps running while Openspot runs" : "keeps running while it is in use"]
            case .once, .inline: []
            }
            for event in script.triggers.events where event != EventName.sheetOpen && event != EventName.sheetText {
                moments.append(event == EventName.panelOpen ? "when the panel opens" : "on \(event)")
            }
            if let every = script.triggers.every { moments.append("every \(every) seconds") }
            return moments.isEmpty ? nil : "\(script.name): \(moments.joined(separator: ", "))"
        }
    }

    private static func bindings(in scan: ScanResult, folder: URL, core: URL?) -> [(binding: Manifest.Binding, shown: String)] {
        let own = Set(scan.scripts.map(\.id))
        var seen: [Manifest.Binding] = []
        for binding in scan.scripts.flatMap(\.bindings) where !seen.contains(binding) { seen.append(binding) }
        return seen.map { binding in
            let isThere = own.contains(binding.spot) || ([folder] + (core.map { [$0] } ?? [])).contains { SpotID(binding.spot).file(in: $0) != nil }
            return (binding, isThere ? binding.line : "\(binding.line), which is not installed")
        }
    }

    private static func canAlso(_ spot: SpotPackage, uses: Set<SpotUse>, id: String) -> [String] {
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
            guard let needed = SpotUseCall(arguments: arguments, of: id), !uses.contains(needed.use) else { continue }
            let line = "Call openspot \(arguments[0]) \(arguments[1]) without \(needed.use.rawValue) in the uses of its spot.toml"
            if !lines.contains(line) { lines.append(line) }
        }
        return lines
    }

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

    private static func listed(_ words: [String]) -> String {
        words.count < 2 ? words.joined() : "\(words.dropLast().joined(separator: ", ")) and \(words.last ?? "")"
    }

    private static func section(_ title: String, _ lines: [String]) -> String? {
        lines.isEmpty ? nil : "\(title)\n\(lines.joined(separator: "\n"))\n\n"
    }

    private static func canShow(_ file: SpotPackage.File) -> Bool {
        file.text != nil && file.contents.count <= textLimit
    }

    private static func shown(_ file: SpotPackage.File) -> String {
        if canShow(file), let text = file.text { return "\(file.path)\n\(text)" }
        let reason = file.text == nil ? "Not text, so Openspot cannot show it." : "Too long to show."
        return "\(file.path)\n\(reason) \(file.contents.count) bytes.\n"
    }
}
