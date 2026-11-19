import Foundation

struct RaycastExtensionImport {
    enum Outcome: String, Encodable, Sendable {
        case use, get, make
    }

    struct Item: Equatable, Encodable, Sendable, PrintedRecord {
        let name: String
        let title: String
        let detail: String
        let outcome: Outcome
        let spot: String?
        let spotTitle: String?
        let icon: String?
        let folder: String

        var blocks: [[(String, String?)]] {
            [[("row", name), ("title", title), ("detail", detail), ("outcome", outcome.rawValue), ("spot", spot), ("spot.title", spotTitle), ("icon", icon), ("folder", folder)]]
        }
    }

    let folder: URL

    func run(catalog: SpotCatalog) -> [Item] {
        let extensions = RaycastExtension.scan(folder)
        guard !extensions.isEmpty else { return [] }
        let items = Dictionary(catalog.items(publications: false).map { ($0.id, $0) }) { first, _ in first }
        let found = extensions.map { found in (found, RaycastAnalog.spot(for: found.name).flatMap { items[$0] }) }
        return found.filter { $0.1 != nil }.map(Self.item) + found.filter { $0.1 == nil }.map(Self.item)
    }

    private static func item(_ found: RaycastExtension, _ spot: SpotCatalog.Item?) -> Item {
        let outcome: Outcome = spot.map { $0.isAdded ? .use : .get } ?? .make
        let detail = switch outcome {
        case .use: "→ \(spot?.spot.name ?? "")"
        case .get: "→ \(spot?.spot.name ?? "") · \(spot?.store == nil ? "turned off" : "in the Store")"
        case .make: found.summary.isEmpty ? "\(found.commands.count) commands" : found.summary
        }
        return Item(name: found.name, title: found.title, detail: detail, outcome: outcome, spot: spot?.id, spotTitle: spot?.spot.name, icon: found.icon?.path, folder: found.folder.path)
    }
}
