import Foundation

/// The spots in the dock of Edit Spots: each spot that is not on the grid, with the place where it shows, and the tab and
/// the search that pick the spots that the dock shows.
public struct SpotDock: Equatable, Sendable {
    /// Where a spot that is not on the grid shows.
    public enum Place: Int, Comparable, Sendable {
        case search, off, fix

        public static func < (lhs: Place, rhs: Place) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// A tab of the dock: every spot, or the spots of one place.
    public enum Tab: CaseIterable, Sendable {
        case all, search, off, fix

        public var title: String {
            switch self {
            case .all: "All"
            case .search: "In search only"
            case .off: "Off"
            case .fix: "Needs a fix"
            }
        }

        func holds(_ place: Place) -> Bool {
            switch self {
            case .all: true
            case .search: place == .search
            case .off: place == .off
            case .fix: place == .fix
            }
        }
    }

    /// One spot in the dock.
    public struct Item: Identifiable, Equatable, Sendable {
        public let command: Spot
        public let place: Place

        public var id: String {
            command.id
        }

        public init(command: Spot, place: Place) {
            self.command = command
            self.place = place
        }
    }

    public let items: [Item]
    public var tab = Tab.all
    public var query = ""

    public init(items: [Item]) {
        self.items = items.sorted { lhs, rhs in
            lhs.place != rhs.place ? lhs.place < rhs.place
                : lhs.command.name.localizedCaseInsensitiveCompare(rhs.command.name) == .orderedAscending
        }
    }

    /// The spots of the tab whose name holds the search, each place in turn and each spot by name.
    public var shown: [Item] {
        items.filter { tab.holds($0.place) && matches($0) }
    }

    /// How many spots this tab shows with the search.
    public func count(of tab: Tab) -> Int {
        items.filter { tab.holds($0.place) && matches($0) }.count
    }

    private func matches(_ item: Item) -> Bool {
        query.isEmpty || item.command.name.localizedStandardContains(query)
    }
}
