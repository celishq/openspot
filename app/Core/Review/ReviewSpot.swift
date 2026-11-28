import Foundation

public struct ReviewSpot: Equatable, Sendable {
    public static let id = "openspot/install"
    static let textLimit = 256_000

    public let shared: SpotPackage
    public let name: String
    public let symbol: String
    public let description: String?
    public let folder: URL
    public let subtitle: String
    public let trust: String
    public let canDo: [String]
    public let uses: [SpotUse]
    public let lines: [ReviewLine]
    private let text: String

    static let noFolder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-none", isDirectory: true)

    public init(spot: SpotPackage, folder: URL, core: URL? = nil) throws {
        if let clash = spot.clash(in: folder) { throw SpotError.fault(clash) }
        let logs = try spot.roots.map { try spot.releaseLog(in: $0) }
        let scan = try Self.scan(of: spot)
        let spots = scan.files.flatMap(\.spots)
        let primary = spot.files.lazy.compactMap { file in spots.first { $0.url.path.hasSuffix("/\(file.path)") } }.first
        guard let primary else { throw SpotError.fault("This file holds no spot.") }
        let runs = Self.selfRuns(in: scan)
        self.shared = spot
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
        self.uses = uses
        let present = spot.files.map(\.path).filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path) }
        let installed = Set(present.flatMap { (try? SpotUse.set(Manifest(beside: folder.appendingPathComponent($0)).script($0).uses, of: $0)) ?? [] })
        let grown = spot.replaced(in: folder).isEmpty ? [] : uses.filter { !installed.contains($0) }
        let marked = Self.canAlso(spot, uses: Set(uses), id: primary.id)
        let canAlso = marked.map { $0.replacingOccurrences(of: "`", with: "") }
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
        lines = [
            ReviewLine(title: ReviewLine.usesTitle, words: [uses.isEmpty ? (canAlso.isEmpty ? "No Mac features" : "None declared") : uses.map(\.rawValue).joined(separator: ", ")]),
            ReviewLine(title: "Runs by itself", words: runs.isEmpty ? [quiet] : runs),
            ReviewLine(title: "Can also", words: marked),
            ReviewLine(title: "Binds", words: bindings.map(\.shown)),
            ReviewLine(title: ReviewLine.filesTitle, words: spot.files.map(\.path).filter { !$0.hasSuffix("/\(ReleaseLog.fileName)") })
        ].filter { !$0.words.isEmpty }
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

    public var summary: String {
        "\(name)\n\n\(trust)" + (Self.section("Files", shared.files.map(\.path).filter { !$0.hasSuffix("/\(ReleaseLog.fileName)") }) ?? "")
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
        return [root, reviewPart.text].joined(separator: "\n")
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
        let runs: [(name: String, moments: [String])] = scan.scripts.compactMap { script in
            var moments: [String] = switch script.mode {
            case .stay: [script.showsAtLaunch ? "keeps running while Openspot runs" : "keeps running while it is in use"]
            case .once, .inline: []
            }
            for event in script.triggers.events where event != EventName.sheetOpen && event != EventName.sheetText {
                if event == EventName.appLaunch, script.mode == .stay, script.showsAtLaunch { continue }
                moments.append(SpotEvent.named(event)?.words ?? "on \(event)")
            }
            if let every = script.triggers.every { moments.append("every \(every) seconds") }
            return moments.isEmpty ? nil : (script.name, moments)
        }
        return runs.map { run in
            let said = run.moments.joined(separator: ", ")
            return runs.count > 1 ? "\(run.name): \(said)" : said.prefix(1).uppercased() + said.dropFirst()
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
        let texts = spot.files.filter { !$0.path.hasSuffix(".\(SpotReadme.fileExtension)") }.compactMap(\.text)
        func has(_ pattern: String) -> Bool {
            let found = try? NSRegularExpression(pattern: pattern)
            return texts.contains { found?.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
        }
        func found(_ tools: [String]) -> [String] {
            tools.filter { tool in
                let word = try? NSRegularExpression(pattern: "(?<![\\w./-])\(tool)(?![\\w-])")
                return texts.contains { word?.firstMatch(in: $0, range: NSRange($0.startIndex..., in: $0)) != nil }
            }
        }
        var lines: [String] = []
        let network = found(["curl", "wget", "nc"])
        if !network.isEmpty, !uses.contains(.network) { lines.append("Reach the network with \(listed(network.map { "`\($0)`" }))") }
        if !found(["rm"]).isEmpty { lines.append("Delete files with `rm`") }
        if !found(["screencapture"]).isEmpty { lines.append("Take screenshots with `screencapture` in place of `openspot screen`") }
        if !found(["pbcopy"]).isEmpty { lines.append("Copy with `pbcopy` in place of `openspot clipboard`") }
        if !found(["pbpaste"]).isEmpty { lines.append("Read the clipboard with `pbpaste` in place of `openspot clipboard`") }
        if has(#"\bAV(AudioEngine|AudioRecorder|CaptureDevice|CaptureSession)\b"#) { lines.append("Record from the microphone or camera") }
        if has(#"\bProcess\(\)|\bNSTask\b|\bposix_spawn\b"#) { lines.append("Start other programs") }
        if !found(["osascript"]).isEmpty { lines.append("Control other apps with `osascript`") }
        if has(#"\$HOME\b|\$\{HOME\}|\bhomeDirectoryForCurrentUser\b|\bNSHomeDirectory\b|"HOME"|(^|[\s"'=(])~/"#) { lines.append("Read files in your home folder") }
        for arguments in texts.flatMap(WrittenCalls.calls) {
            guard let needed = SpotUseCall(arguments: arguments, of: id), !uses.contains(needed.use) else { continue }
            let line = "Call `openspot \(arguments[0]) \(arguments[1])` without `\(needed.use.rawValue)` in the uses of its `spot.toml`"
            if !lines.contains(line) { lines.append(line) }
        }
        return lines
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
