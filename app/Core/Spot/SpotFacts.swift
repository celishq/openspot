import Foundation

public struct SpotFacts: Equatable, Sendable {
    public let id: String
    public let name: String
    public internal(set) var url: URL
    public let size: SpotSize
    public let headerIcon: Icon?
    let baseSymbol: String
    public let subtitle: String?
    public let read: SpotRead?
    public let offeredPlaces: Set<Place>
    public let isFound: Bool
    public let answers: AnswerPattern?
    public internal(set) var order: Int
    public let layout: WidgetLayout?
    public let places: [String]
    public let opens: String?
    public let host: HostSheet?
    public let growsFromField: Bool
    public internal(set) var mode: SpotMode
    public let pressRuns: Bool
    public let drop: [String]
    public let dataName: String?
    public internal(set) var isOnGrid: Bool
    public internal(set) var view: String?
    public let viewDate: Date?
    public internal(set) var sources: [String]
    public let emits: [String]
    public let pages: [String]
    public internal(set) var uses: Set<SpotUse>
    public let offers: [HeaderButton]
    public internal(set) var offeredActions: [OfferedAction]
    public let settings: [HeaderField]
    public internal(set) var holdsSettings = false
    public internal(set) var isBuiltIn = false
    public internal(set) var isRestricted = false
    public internal(set) var grant: Trusted?
    public let keywords: [String]
    public let placeholder: String?
    public let sample: URL?
    public let edits: SpotEdits?
    public internal(set) var editedFile: URL?

    public var editsSpots: Bool {
        edits == .spots
    }
}
