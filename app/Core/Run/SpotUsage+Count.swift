import Foundation

extension SpotUsage {
    public struct Count: Codable, Equatable, Sendable {
        public var name: String?
        public var runs = 0
        public var seconds: TimeInterval = 0
        public var calls: [String: Int] = [:]
        public var network = false
        public var fault: String?
        public var view: ViewTime?
        public var acts = 0
        public var last: Date?
        public var reads: [String: Int] = [:]
        public var cost = ProcessTime.zero
        public var hidden = ProcessTime.zero
        public var answers = AnswerTimes()
        public var failures = Failures()

        static let actGap: TimeInterval = 2

        mutating func act(at date: Date) {
            if let last, date.timeIntervalSince(last) < Self.actGap { return }
            acts += 1
            last = date
        }

        mutating func call(seconds: TimeInterval, answered: TimeInterval?, failure: Failure?, reason: String?, network: Bool, at date: Date) {
            runs += 1
            self.seconds += seconds
            if let answered { answers.add(answered) }
            if let failure { failures.add(failure, at: date) }
            if let reason { reads[reason, default: 0] += 1 }
            self.network = network
        }

        mutating func add(_ time: ProcessTime, hidden isHidden: Bool) {
            cost = cost + time
            if isHidden { hidden = hidden + ProcessTime(cpu: time.cpu, wakeups: time.wakeups) }
        }

        func adding(_ older: Count) -> Count {
            var sum = self
            sum.name = name ?? older.name
            sum.runs += older.runs
            sum.seconds += older.seconds
            sum.calls.merge(older.calls, uniquingKeysWith: +)
            sum.network = network || older.network
            sum.fault = fault ?? older.fault
            sum.view = view.map { $0.adding(older.view) } ?? older.view
            sum.acts += older.acts
            sum.last = [last, older.last].compactMap { $0 }.max()
            sum.reads.merge(older.reads, uniquingKeysWith: +)
            sum.cost = cost + older.cost
            sum.hidden = hidden + older.hidden
            sum.answers = answers + older.answers
            sum.failures = failures + older.failures
            return sum
        }
    }

    public struct AnswerTimes: Equatable, Sendable {
        static let bounds: [TimeInterval] = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2, 6.4]

        public private(set) var counts: [Int] = []

        public var total: Int {
            counts.reduce(0, +)
        }

        mutating func add(_ seconds: TimeInterval) {
            if counts.isEmpty { counts = Array(repeating: 0, count: Self.bounds.count + 1) }
            counts[Self.bounds.firstIndex { seconds <= $0 } ?? Self.bounds.count] += 1
        }

        public func time(_ share: Double) -> TimeInterval? {
            guard total > 0 else { return nil }
            let target = Int((share * Double(total)).rounded(.up))
            var seen = 0
            for (index, count) in counts.enumerated() {
                seen += count
                if seen >= target { return Self.bounds[min(index, Self.bounds.count - 1)] }
            }
            return Self.bounds.last
        }

        static func + (left: AnswerTimes, right: AnswerTimes) -> AnswerTimes {
            if left.counts.isEmpty { return right }
            if right.counts.isEmpty { return left }
            return AnswerTimes(counts: zip(left.counts, right.counts).map(+))
        }
    }

    public struct Failures: Equatable, Sendable {
        public var count = 0
        public var kinds: [String: Int] = [:]
        public var last: Date?

        mutating func add(_ kind: Failure, at date: Date) {
            count += 1
            kinds[kind.rawValue, default: 0] += 1
            last = date
        }

        static func + (left: Failures, right: Failures) -> Failures {
            Failures(count: left.count + right.count, kinds: left.kinds.merging(right.kinds, uniquingKeysWith: +), last: [left.last, right.last].compactMap { $0 }.max())
        }
    }
}

extension SpotUsage.Count {
    private enum CodingKeys: String, CodingKey {
        case name, runs, seconds, calls, network, fault, view, acts, last, reads
        case cpu, read, written, wakeups, memory, hiddenCPU, hiddenWakeups, answers, failures, failureKinds, failed
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        func number<Value: Decodable & Numeric>(_ key: CodingKeys) throws -> Value { try values.decodeIfPresent(Value.self, forKey: key) ?? 0 }
        name = try values.decodeIfPresent(String.self, forKey: .name)
        runs = try number(.runs)
        seconds = try number(.seconds)
        calls = try values.decodeIfPresent([String: Int].self, forKey: .calls) ?? [:]
        network = try values.decodeIfPresent(Bool.self, forKey: .network) ?? false
        fault = try values.decodeIfPresent(String.self, forKey: .fault)
        view = try values.decodeIfPresent(SpotUsage.ViewTime.self, forKey: .view)
        acts = try number(.acts)
        last = try values.decodeIfPresent(Date.self, forKey: .last)
        reads = try values.decodeIfPresent([String: Int].self, forKey: .reads) ?? [:]
        cost = ProcessTime(cpu: try number(.cpu), wakeups: try number(.wakeups), read: try number(.read), written: try number(.written), memory: try number(.memory))
        hidden = ProcessTime(cpu: try number(.hiddenCPU), wakeups: try number(.hiddenWakeups))
        answers = SpotUsage.AnswerTimes(counts: try values.decodeIfPresent([Int].self, forKey: .answers) ?? [])
        failures = SpotUsage.Failures(count: try number(.failures), kinds: try values.decodeIfPresent([String: Int].self, forKey: .failureKinds) ?? [:], last: try values.decodeIfPresent(Date.self, forKey: .failed))
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encodeIfPresent(name, forKey: .name)
        try values.encode(runs, forKey: .runs)
        try values.encode(seconds, forKey: .seconds)
        try values.encode(calls, forKey: .calls)
        try values.encode(network, forKey: .network)
        try values.encodeIfPresent(fault, forKey: .fault)
        try values.encodeIfPresent(view, forKey: .view)
        try values.encode(acts, forKey: .acts)
        try values.encodeIfPresent(last, forKey: .last)
        try values.encode(reads, forKey: .reads)
        try values.encode(cost.cpu, forKey: .cpu)
        try values.encode(cost.wakeups, forKey: .wakeups)
        try values.encode(cost.read, forKey: .read)
        try values.encode(cost.written, forKey: .written)
        try values.encode(cost.memory, forKey: .memory)
        try values.encode(hidden.cpu, forKey: .hiddenCPU)
        try values.encode(hidden.wakeups, forKey: .hiddenWakeups)
        try values.encode(answers.counts, forKey: .answers)
        try values.encode(failures.count, forKey: .failures)
        try values.encode(failures.kinds, forKey: .failureKinds)
        try values.encodeIfPresent(failures.last, forKey: .failed)
    }
}
