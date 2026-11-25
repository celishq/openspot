import Foundation

public struct AccessFacts: Equatable, Sendable {
    public private(set) var all: [AccessList.Entry] = []
    public private(set) var needed: [AccessList.Entry] = []
    public private(set) var unneeded: [AccessList.Entry] = []

    public init() {}

    init(_ entries: [AccessList.Entry]) {
        all = entries
        needed = entries.filter { !$0.spots.isEmpty }
        unneeded = entries.filter { $0.spots.isEmpty }
    }

    public func access(_ id: MacAccess) -> AccessList.Entry? {
        all.first { $0.id == id }
    }
}
