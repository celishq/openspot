import Foundation

public struct RecentCache<Key: Hashable, Value> {
    private struct Kept {
        let value: Value
        let cost: Int
        var use: Int
    }

    private let base: Int
    private var kept: [Key: Kept] = [:]
    private var uses = 0
    private var largest = 0
    public private(set) var bytes = 0

    public init(base: Int) {
        self.base = base
    }

    public var limit: Int {
        base + 2 * largest
    }

    public var room: Int {
        limit - bytes
    }

    public mutating func value(for key: Key) -> Value? {
        guard var found = kept[key] else { return nil }
        uses += 1
        found.use = uses
        kept[key] = found
        return found.value
    }

    public mutating func keep(_ value: Value, for key: Key, cost: Int) {
        if let old = kept.removeValue(forKey: key) { bytes -= old.cost }
        largest = max(largest, cost)
        uses += 1
        kept[key] = Kept(value: value, cost: cost, use: uses)
        bytes += cost
        while bytes > limit, let oldest = kept.min(by: { $0.value.use < $1.value.use }), oldest.key != key {
            kept[oldest.key] = nil
            bytes -= oldest.value.cost
        }
    }
}
