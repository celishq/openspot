import Foundation

/// A part of the person's calendars that macOS guards with a leave of its own: the events or the reminders.
public protocol CalendarStore {
    func access() -> CalendarAccess
    /// Asks macOS for leave, which shows its prompt the first time, and returns the answer.
    func ask() async -> CalendarAccess
}

extension CalendarStore {
    /// Whether it may be read. A read that has not asked returns false, a call outside a read asks first, and a refusal
    /// fails with the pane that fixes it (E8).
    func isAllowed(isRead: Bool, refusal: String, pane: URL) async throws -> Bool {
        var access = access()
        if access == .unasked {
            guard !isRead else { return false }
            access = await ask()
        }
        guard access == .allowed else { throw SpotError.failedWithFix(1, refusal, pane) }
        return true
    }
}
