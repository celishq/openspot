import Foundation

struct SpotAsks {
    private var waiting: [String: CheckedContinuation<String?, Never>] = [:]

    func isWaiting(for id: String) -> Bool {
        waiting[id] != nil
    }

    mutating func wait(for id: String, _ continuation: CheckedContinuation<String?, Never>) {
        end(id)
        waiting[id] = continuation
    }

    mutating func reply(_ value: String, from id: String) -> Bool {
        guard let ask = waiting.removeValue(forKey: id) else { return false }
        ask.resume(returning: value)
        return true
    }

    mutating func end(_ id: String) {
        waiting.removeValue(forKey: id)?.resume(returning: nil)
    }

    mutating func endAll() {
        waiting.keys.forEach { end($0) }
    }
}
