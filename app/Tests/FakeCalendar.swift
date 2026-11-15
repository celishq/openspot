import Foundation
@testable import OpenspotCore

struct FakeCalendar: MacCalendar {
    var made: @Sendable () -> any EventStore = { FakeEventStore() }

    func store() -> any EventStore {
        made()
    }

    func show(_ time: Date) throws {}
}
