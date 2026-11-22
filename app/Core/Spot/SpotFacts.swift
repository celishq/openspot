import Foundation

public struct SpotFacts: Equatable, Sendable {
    public let id: String
    public let name: String
    public internal(set) var url: URL
    public let size: SpotSize
    public let headerIcon: Icon?
    let baseSymbol: String
    public let subtitle: String?
    public let on: ShowEvents?
    public let hasSheet: Bool
    public let isGlobal: Bool
    public let isFound: Bool
    public let answers: AnswerPattern?
    public internal(set) var order: Int
    public let host: HostSheet?
    public let growsFromField: Bool
    public internal(set) var mode: SpotMode
    public let drop: [String]
    public let dataName: String?
    public internal(set) var isOnGrid: Bool
    public let views: [String: String]
    public let viewDates: [String: Date]
    public internal(set) var sources: [String]
    public let emits: [String]
    public let pages: [String]
    public internal(set) var uses: Set<SpotUse>
    public let offers: [Manifest.Command]
    public internal(set) var offeredActions: [OfferedAction]
    public let settings: [Manifest.Setting]
    public internal(set) var holdsSettings = false
    public internal(set) var isBuiltIn = false
    public let keywords: [String]
    public let placeholder: String?
    public let sample: URL?
    public let edits: SpotEdits?
    public let starts: SpotStart?
    public internal(set) var editedFile: URL?

    public var kinds: [BlockKind] {
        BlockKind.kinds(views: views)
    }

    public var editsSpots: Bool {
        edits == .spots
    }
}
