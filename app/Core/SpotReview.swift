import Foundation

/// What a person sees before they add a shared spot: its whole text and what runs by itself. It learns this from the text
/// of the files, and runs none of them.
public struct SpotReview: Equatable, Sendable {
    public let spot: SharedSpot
    public let name: String
    public let folder: URL
    public let subtitle: String
    private let text: String

    /// Reads a spot for a plugins folder. Throws a fault when it gives no spot or cannot go into that folder.
    public init(spot: SharedSpot, name: String, folder: URL) throws {
        if let clash = spot.clash(in: folder) { throw PluginError.fault(clash) }
        let scan = try Self.scan(of: spot)
        guard scan.plugins.contains(where: { !$0.commands.isEmpty }) else { throw PluginError.fault("This file holds no spot.") }
        let runs = Self.selfRuns(in: scan)
        self.spot = spot
        self.name = name
        self.folder = folder
        subtitle = runs.isEmpty ? "Runs only when you use it" : "Runs by itself"
        text = [
            Self.section("Runs by itself", runs),
            Self.section("Replaces, and moves the old file to the Trash", spot.replaced(in: folder)),
            Self.section("Will not load", scan.refused.map { "\($0.file): \($0.reason)" })
        ].compactMap { $0 }.joined() + spot.files.map(Self.shown).joined(separator: "\n")
    }

    /// Answers one call with the text a script would print.
    public func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            return sheet
        case "add":
            try spot.add(to: folder)
            return TextBlock(fields: [.init(key: "toast", value: "\(name) added")]).text
        default:
            throw PluginError.failed(1, "This sheet cannot do that.")
        }
    }

    private var sheet: String {
        [
            TextBlock(fields: [.init(key: "grid", value: "t"), .init(key: "grid", value: "a")]).text,
            TextBlock(fields: [
                .init(key: "part", value: "review"),
                .init(key: "cell", value: "t"),
                .init(key: "fill", value: "true"),
                .init(key: "readonly", value: "true"),
                .init(key: "text", value: text)
            ]).text,
            TextBlock(fields: [
                .init(key: "part", value: "add"),
                .init(key: "cell", value: "a"),
                .init(key: "title", value: "Add"),
                .init(key: "press", value: "true"),
                .init(key: "key", value: "cmd+return"),
                .init(key: "close", value: "true"),
                .init(key: "look", value: "strong")
            ]).text
        ].joined(separator: "\n")
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

    private static func shown(_ file: SharedSpot.File) -> String {
        "\(file.path)\n\(file.text ?? "Not text, so Openspot cannot show it. \(file.contents.count) bytes.\n")"
    }
}
