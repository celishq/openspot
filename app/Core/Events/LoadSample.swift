import Foundation

public struct LoadSample: Equatable, Sendable {
    public let busy: UInt64
    public let total: UInt64
    public let memory: Int

    public init(busy: UInt64, total: UInt64, memory: Int) {
        self.busy = busy
        self.total = total
        self.memory = memory
    }

    func value(since earlier: LoadSample) -> String {
        let spent = total &- earlier.total
        let cpu = spent == 0 || spent > total ? 0 : Int((Double(busy &- earlier.busy) / Double(spent) * 100).rounded())
        return "cpu=\(min(max(cpu, 0), 100)) memory=\(min(max(memory, 0), 100))"
    }
}
