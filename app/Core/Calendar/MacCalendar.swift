import Foundation

public protocol MacCalendar: Sendable {
    func store() -> any EventStore
    func show(_ time: Date) throws
}
