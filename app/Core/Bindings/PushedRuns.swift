import Foundation

struct PushedRuns {
    private var waiting: [String: (action: Manifest.Action, end: CheckedContinuation<RunEnd, Never>)] = [:]

    func isWaiting(for id: String) -> Bool {
        waiting[id] != nil
    }

    mutating func wait(for id: String, action: Manifest.Action, _ end: CheckedContinuation<RunEnd, Never>) {
        self.end(id, .cancelled)
        waiting[id] = (action, end)
    }

    mutating func answer(_ lines: Frame, from id: String) {
        guard let action = waiting[id]?.action else { return }
        if let message = lines.root?.value(RootKey.error.rawValue) { return end(id, .failed(message)) }
        if let fault = action.fault(in: lines.outputs) { return end(id, .failed(fault)) }
        end(id, .values(lines.outputs))
    }

    mutating func end(_ id: String, _ end: RunEnd) {
        waiting.removeValue(forKey: id)?.end.resume(returning: end)
    }

    mutating func endAll() {
        waiting.keys.forEach { end($0, .cancelled) }
    }
}
