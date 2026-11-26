import Foundation

public struct SpotStandings: Equatable, Sendable {
    public struct Group: Identifiable, Equatable, Sendable {
        public let id: String
        public let standings: [SpotStanding]
    }

    public private(set) var all: [SpotStanding] = []
    public private(set) var groups: [Group] = []
    public private(set) var waiting: [SpotStanding] = []

    public init() {}

    init(loaded: [SpotStanding]) {
        var seen = Set<String>()
        all = loaded
            .filter { !$0.id.hasPrefix(ReservedSetting.appSpot + "/") && seen.insert($0.id).inserted }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        waiting = all.filter(\.lacks)
        groups = [
            Group(id: "Needs Attention", standings: waiting),
            Group(id: "Ready", standings: all.filter { !$0.lacks })
        ].filter { !$0.standings.isEmpty }
    }

    public func standing(_ id: String) -> SpotStanding? {
        all.first { $0.id == id }
    }
}
