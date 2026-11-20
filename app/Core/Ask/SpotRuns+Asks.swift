import Foundation

extension SpotRuns {
    func ask(_ id: String) async -> String? {
        await withCheckedContinuation { asks.wait(for: id, $0) }
    }

    func reply(_ value: String, from id: String) -> Bool {
        asks.reply(value, from: id)
    }

    func settleAsk(of id: String) {
        guard asks.isWaiting(for: id), let sheet = sheets[id], !sheet.isOpen, sheet.calls.allSatisfy(\.isStopped) else { return }
        asks.end(id)
    }
}
