import Foundation

/// The spots in the dock of Edit Spots: each spot that is off, which the person can turn on, and the search that picks the
/// spots that the dock shows.
public struct SpotDock: Equatable, Sendable {
    /// One spot in the dock.
    public struct Item: Identifiable, Equatable, Sendable {
        public let command: Spot

        public var id: String {
            command.id
        }

        public init(command: Spot) {
            self.command = command
        }
    }

    public let items: [Item]
    public var query = ""

    public init(items: [Item]) {
        self.items = items.sorted { $0.command.name.localizedCaseInsensitiveCompare($1.command.name) == .orderedAscending }
    }

    /// The spots whose name, or the words under it, hold the search, by name.
    public var shown: [Item] {
        query.isEmpty ? items : items.filter { item in
            [item.command.name, item.command.subtitle ?? ""].contains { $0.localizedStandardContains(query) }
        }
    }
}
