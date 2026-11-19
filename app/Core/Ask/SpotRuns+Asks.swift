import Foundation

extension SpotRuns {
    func ask(_ id: String) async -> String? {
        asks.removeValue(forKey: id)?.resume(returning: nil)
        return await withCheckedContinuation { asks[id] = $0 }
    }

    func reply(_ value: String, from id: String) -> Bool {
        guard let ask = asks.removeValue(forKey: id) else { return false }
        ask.resume(returning: value)
        onReport(id, .replied)
        return true
    }

    func settleAsk(of id: String) {
        guard asks[id] != nil, let sheet = sheets[id], !sheet.isOpen, sheet.calls.allSatisfy(\.isStopped) else { return }
        asks.removeValue(forKey: id)?.resume(returning: nil)
    }
}
