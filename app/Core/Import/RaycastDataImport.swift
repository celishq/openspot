import Foundation

struct RaycastDataImport {
    let file: URL
    let passphrase: String

    func run(in spots: SpotsFolder, environment: [String: String], isDry: Bool, skip: Set<String> = []) async throws -> [RaycastImport.Item] {
        guard FileManager.default.fileExists(atPath: file.path) else { throw SpotError.failed(1, "There is no file \(file.path).") }
        let export: RaycastExport
        if passphrase.isEmpty {
            guard let opened = RaycastExports.shared.export(of: file) else { throw SpotError.failed(1, "Enter the passphrase again. Openspot closes the export when it quits.") }
            export = opened
        } else {
            guard let data = try? Data(contentsOf: file) else { throw SpotError.failed(1, "There is no file \(file.path).") }
            export = try RaycastExport.read(data, passphrase: passphrase)
            RaycastExports.shared.keep(export, of: file)
        }
        let scripts = ((try? spots.scan().scripts) ?? []) + spots.coreChoices()
        var items = [
            skip.contains("links") ? Self.leftOut("links", "Quicklinks") : try await take(export.quicklinks, key: "links", title: "Quicklinks", into: scripts, environment: environment, isDry: isDry),
            skip.contains("snippets") ? Self.leftOut("snippets", "Snippets") : try await take(export.snippets, key: "snippets", title: "Snippets", into: scripts, environment: environment, isDry: isDry)
        ]
        let rest = [(export.rest.hotkeys, "hotkeys", "Hotkeys"), (export.rest.aliases, "aliases", "Aliases"),
                    (export.rest.favorites, "favorites", "Favorites"), (export.rest.clips, "clipboard", "Clipboard history")]
        for (count, id, title) in rest where count > 0 {
            items.append(RaycastImport.Item(file: id, title: "\(title) · \(count)", id: nil, outcome: .skipped, reason: "Openspot has no place for them yet"))
        }
        return items
    }

    private static func leftOut(_ key: String, _ title: String) -> RaycastImport.Item {
        RaycastImport.Item(file: key, title: title, id: key, outcome: .skipped, reason: "Left out")
    }

    private func take(_ list: [some Encodable], key: String, title: String, into scripts: [Spot], environment: [String: String], isDry: Bool) async throws -> RaycastImport.Item {
        guard !list.isEmpty else { return RaycastImport.Item(file: key, title: title, id: nil, outcome: .skipped, reason: "None in the export") }
        guard let spot = scripts.first(where: { $0.id == key }) else {
            return RaycastImport.Item(file: key, title: title, id: nil, outcome: .skipped, reason: "\(list.count) in the export, and Openspot has no spot \(key)")
        }
        guard !isDry else { return RaycastImport.Item(file: key, title: title, id: key, outcome: .added, reason: "\(list.count) to add to \(spot.name)") }
        let json = String(decoding: try JSONEncoder().encode(list), as: UTF8.self)
        var toast: String?
        let input = TextBlock(fields: [.init(key: "input.\(key)", value: json)]).text
        let end = await TerminalRun(spot: spot, arguments: ["import"], input: input, careful: nil, callers: nil, environment: environment, folder: nil).start { frame in
            toast = TextBlock.blocks(in: frame).first { $0.fields.first == .init(key: "text", value: "added") }?.value("title") ?? toast
        }
        guard end.code == 0 else {
            let reason = end.errors.split(separator: "\n").last.map(String.init) ?? "it stopped with code \(end.code)"
            return RaycastImport.Item(file: key, title: title, id: key, outcome: .skipped, reason: "\(spot.name) could not take them: \(reason)")
        }
        guard let toast else {
            let reason = "\(spot.name) did not take them. Your copy in the spots folder may be older than the one in Openspot: update it, then import again."
            return RaycastImport.Item(file: key, title: title, id: key, outcome: .skipped, reason: reason)
        }
        return RaycastImport.Item(file: key, title: title, id: key, outcome: .added, reason: "\(toast) to \(spot.name)")
    }
}
