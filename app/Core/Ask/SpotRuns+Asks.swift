import Foundation

extension SpotRuns {
    func ask(_ id: String) async -> String? {
        await withCheckedContinuation { asks.wait(for: id, $0) }
    }

    func reply(_ value: String, from id: String) -> Bool {
        guard asks.reply(value, from: id) else { return false }
        onReport(id, .replied)
        return true
    }

    func settleAsk(of id: String) {
        guard asks.isWaiting(for: id), let sheet = sheets[id], !sheet.isOpen, sheet.calls.allSatisfy(\.isStopped) else { return }
        asks.end(id)
    }
}
