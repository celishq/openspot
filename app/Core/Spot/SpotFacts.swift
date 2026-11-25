import Foundation

public struct SpotFacts: Equatable, Sendable {
    public let id: String
    public let name: String
    public internal(set) var url: URL
    public let size: SpotSize
    public let headerIcon: Icon?
    let baseSymbol: String
    public let subtitle: String?
    public let hasSheet: Bool
    public let isFound: Bool
    public let isSource: Bool
    public internal(set) var order: Int
    public let host: HostSheet?
    public let growsFromField: Bool
    public internal(set) var mode: SpotMode
    public let dataName: String?
    public internal(set) var isOnGrid: Bool
    public let views: [String: String]
    public let viewDates: [String: Date]
    public internal(set) var sources: [String]
    public let pages: [String]
    public internal(set) var uses: Set<SpotUse>
    public let commands: [Manifest.Action]
    public internal(set) var offeredActions: [OfferedAction]
    public internal(set) var actions: [Manifest.Action] = []
    public let triggers: Manifest.Triggers
    public internal(set) var bindings: [Manifest.Binding] = []
    public internal(set) var events: [Manifest.Event] = []
    public let settings: [Manifest.Setting]
    public internal(set) var isBuiltIn = false
    public let keywords: [String]
    public let sample: URL?
    public let edits: SpotEdits?
    public let starts: SpotStart?
    public let window: WindowSize?
    public internal(set) var editedFile: URL?

    public var kinds: [BlockKind] {
        BlockKind.kinds(views: views)
    }

    public var editsSpots: Bool {
        edits == .spots
    }
}
