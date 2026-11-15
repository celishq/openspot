import Foundation

public protocol MacReminders: Sendable {
    func store() -> any ReminderStore
    func open(_ link: URL) -> Bool
}
