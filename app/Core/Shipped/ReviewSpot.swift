import Foundation

/// What a person sees before they add a shared spot: its whole text and what runs by itself. It learns this from the text
/// of the files, and runs none of them.
public struct ReviewSpot: Equatable, Sendable {
    static let textLimit = 256_000
    private static let installPart = "install"

    public let spot: SharedSpot
    public let name: String
    public let symbol: String
    public let description: String?
    public let folder: URL
    public let subtitle: String
    private let text: String
    private let canAdd: Bool

    /// Reads a spot for a plugins folder. Throws a fault when it gives no spot or cannot go into that folder. With `canAdd`
    /// false it only shows the text.
    public init(spot: SharedSpot, folder: URL, canAdd: Bool = true) throws {
        if let clash = spot.clash(in: folder) { throw PluginError.fault(clash) }
        let scan = try Self.scan(of: spot)
        let commands = scan.plugins.flatMap(\.commands)
        let primary = spot.files.lazy.compactMap { file in commands.first { $0.url.path.hasSuffix("/\(file.path)") } }.first
        guard let primary else { throw PluginError.fault("This file holds no spot.") }
        let runs = Self.selfRuns(in: scan)
        self.spot = spot
        self.canAdd = canAdd
        name = primary.name
        symbol = primary.symbol
        description = primary.subtitle
        self.folder = folder
        let programs = spot.files.filter { ($0.isExecutable || ViewLibrary.isLibrary($0.path)) && !Self.canShow($0) }.map(\.path)
        let quiet = "Runs only when you use it"
        subtitle = !programs.isEmpty ? "Holds a program that you cannot read" : primary.subtitle ?? (runs.isEmpty ? quiet : "Runs by itself")
        text = [
            programs.isEmpty ? nil : Self.section(
                "Program that Openspot cannot show",
                programs + ["It can do all that you can. Add it only if you trust the sender."]
                    + (programs.contains { Self.hasSource($0, in: spot) } ? ["The source beside it may not match the program."] : [])
            ),
            runs.isEmpty ? "\(quiet)\n\n" : Self.section("Runs by itself", runs),
            Self.section("Replaces, and moves the old file to the Trash", spot.replaced(in: folder)),
            Self.section("Will not load", scan.refused.map { "\($0.file): \($0.reason)" })
        ].compactMap { $0 }.joined() + spot.files.map(Self.shown).joined(separator: "\n")
    }

    /// Answers one call with the text a script would print.
    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            return sheet
        case Self.installPart where canAdd:
            try spot.add(to: folder)
            return TextBlock(fields: [.init(key: "toast", value: "\(name) added")]).text
        default:
            throw PluginError.failed(1, "This sheet cannot do that.")
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
            .init(key: "text", value: text)
        ])
    }

    /// Reads the spot as a scan would, from a folder that holds only its files.
    private static func scan(of spot: SharedSpot) throws -> ScanResult {
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-review-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: place) }
        try spot.add(to: place)
        return try PluginFolder(url: place).scan()
    }

    /// A line for each script that runs with no act of a person, which says when.
    private static func selfRuns(in scan: ScanResult) -> [String] {
        let placed = Set(scan.plugins.flatMap(\.commands).flatMap(\.places))
        return scan.scripts.compactMap { script in
            var moments = script.stays ? ["keeps running while it is in use"] : []
            for moment in script.read?.moments ?? [] {
                switch moment {
                case .panel: moments.append("when the panel opens")
                case .wake: moments.append("when the Mac wakes")
                case .launch: moments.append("when Openspot starts")
                case .every(let seconds): moments.append("every \(Int(seconds)) seconds")
                case .sheet: break
                }
            }
            if placed.contains(script.id), script.read?.seconds == nil, script.read?.has(.panel) != true {
                moments.append("when the panel opens")
            }
            return moments.isEmpty ? nil : "\(script.name): \(moments.joined(separator: ", "))"
        }
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
