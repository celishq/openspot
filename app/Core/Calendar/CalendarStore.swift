import Foundation

public protocol CalendarStore {
    func access() -> CalendarAccess
    func ask() async -> CalendarAccess
}

extension CalendarStore {
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
