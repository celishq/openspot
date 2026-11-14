import Foundation

public final class SpotUsage: @unchecked Sendable {
    public struct Count: Codable, Equatable, Sendable {
        public var name: String?
        public var runs = 0
        public var failures = 0
        public var seconds: TimeInterval = 0
        public var cpu: TimeInterval = 0
        public var read: UInt64 = 0
        public var written: UInt64 = 0
        public var wakeups: UInt64 = 0
        public var calls: [String: Int] = [:]
        public var network = false
        public var fault: String?

        mutating func add(_ time: ProcessTime) {
            cpu += time.cpu
            read += time.read
            written += time.written
            wakeups += time.wakeups
        }

        func adding(_ older: Count) -> Count {
            var sum = self
            sum.name = name ?? older.name
            sum.runs += older.runs
            sum.failures += older.failures
            sum.seconds += older.seconds
            sum.cpu += older.cpu
            sum.read += older.read
            sum.written += older.written
            sum.wakeups += older.wakeups
            sum.calls.merge(older.calls, uniquingKeysWith: +)
            sum.network = network || older.network
            sum.fault = fault ?? older.fault
            return sum
        }
    }

    public struct Use: Codable, Equatable, Sendable {
        public let time: Date
        public let spot: String
        public let call: String
        public let declared: Bool
    }

    public struct Day: Codable, Equatable, Sendable {
        public let day: String
        public var spots: [String: Count] = [:]
        public var uses: [Use] = []
        var told: [String] = []
    }

    static let keptDays = 90
    private static let useLimit = 100

    private let folder: URL?
    private let pause: TimeInterval
    private let lock = NSLock()
    private let writes = DispatchQueue(label: "dev.openspot.stats")
    private var today: Day
    private var isDirty = false
    private var isWaiting = false
    private var live: [ObjectIdentifier: (spot: String, process: ScriptProcess, counted: ProcessTime)] = [:]
    let now: () -> Date

    public init(folder: URL? = nil, at date: Date = Date(), pause: TimeInterval = 60, now: @escaping () -> Date = { Date() }) {
        self.folder = folder
        self.pause = pause
        self.now = now
        let day = Self.day(of: date)
        today = folder.flatMap { Self.read(day, in: $0) } ?? Day(day: day)
        if let folder { Self.prune(folder, at: date) }
    }

    public var counts: [String: Count] {
        lock.withLock { withLive(today).spots }
    }

    public func days(_ count: Int, at date: Date) -> [Day] {
        writes.sync {}
        let now = lock.withLock { Self.day(of: date) == today.day ? withLive(today) : nil }
        return Self.days(count, at: date, today: now, in: folder)
    }

    public static func days(_ count: Int, at date: Date, today: Day? = nil, in folder: URL?) -> [Day] {
        (0..<max(count, 1)).compactMap { back in
            let name = day(of: Calendar.current.date(byAdding: .day, value: -back, to: date) ?? date)
            if let today, today.day == name { return today }
            return folder.flatMap { read(name, in: $0) }
        }
    }

    func track(_ process: ScriptProcess, of spot: String) {
        let key = ObjectIdentifier(process)
        lock.withLock { live[key] = (spot, process, .zero) }
        process.onExit { [weak self] time in
            guard let self, let ended = lock.withLock({ live.removeValue(forKey: key) }) else { return }
            add(time.since(ended.counted), to: ended.spot, at: now())
        }
    }

    func add(_ time: ProcessTime, to spot: String, at date: Date) {
        change(at: date) { $0.spots[spot, default: Count()].add(time) }
    }

    func called(_ spot: Spot, seconds: TimeInterval, isFailure: Bool, at date: Date) {
        change(at: date) { day in
            day.spots[spot.id, default: Count()].name = spot.name
            day.spots[spot.id, default: Count()].runs += 1
            day.spots[spot.id, default: Count()].seconds += seconds
            if isFailure { day.spots[spot.id, default: Count()].failures += 1 }
            day.spots[spot.id, default: Count()].network = spot.uses.contains(.network)
        }
    }

    func failedRun(_ spot: Spot, at date: Date) {
        change(at: date) { day in
            day.spots[spot.id, default: Count()].name = spot.name
            day.spots[spot.id, default: Count()].failures += 1
        }
    }

    func failed(_ spot: Spot, fault: String, at date: Date) {
        change(at: date) { day in
            day.spots[spot.id, default: Count()].name = spot.name
            day.spots[spot.id, default: Count()].fault = fault
        }
    }

    func used(_ call: SpotUseCall, by caller: CallerTokens.Caller, at date: Date) -> Bool {
        let declared = caller.uses.contains(call.use)
        var tells = false
        change(at: date) { day in
            day.spots[caller.id, default: Count()].name = caller.name
            day.spots[caller.id, default: Count()].calls[call.name, default: 0] += 1
            day.spots[caller.id, default: Count()].network = caller.uses.contains(.network)
            day.uses = Array((day.uses + [Use(time: date, spot: caller.id, call: call.name, declared: declared)]).suffix(Self.useLimit))
            let told = "\(caller.id) \(call.use.rawValue)"
            if !declared, !day.told.contains(told) {
                day.told.append(told)
                tells = true
            }
        }
        return tells
    }

    public func flush() {
        let date = now()
        let ended: Day? = lock.withLock {
            let ended = roll(to: date)
            if countLive(into: &today) { isDirty = true }
            return ended
        }
        guard let folder else { return }
        writes.sync {
            if let ended { Self.write(ended, in: folder) }
            let day: Day? = lock.withLock {
                isWaiting = false
                guard isDirty else { return nil }
                isDirty = false
                return today
            }
            if let day { Self.write(day, in: folder) }
        }
        if ended != nil { Self.prune(folder, at: date) }
    }

    static func day(of date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private func change(at date: Date? = nil, _ work: (inout Day) -> Void) {
        let (ended, waits): (Day?, Bool) = lock.withLock {
            let ended = date.flatMap(roll)
            work(&today)
            isDirty = true
            defer { isWaiting = true }
            return (ended, !isWaiting)
        }
        guard let folder else { return }
        if let ended {
            writes.async {
                Self.write(ended, in: folder)
                if let date { Self.prune(folder, at: date) }
            }
        }
        if waits {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + pause) { [weak self] in self?.flush() }
        }
    }

    private func roll(to date: Date) -> Day? {
        guard Self.day(of: date) != today.day else { return nil }
        if countLive(into: &today) { isDirty = true }
        let ended = isDirty ? today : nil
        today = folder.flatMap { Self.read(Self.day(of: date), in: $0) } ?? Day(day: Self.day(of: date))
        return ended
    }

    private func countLive(into day: inout Day) -> Bool {
        var counted = false
        for (key, entry) in live {
            let time = entry.process.time
            let spent = time.since(entry.counted)
            guard spent != .zero else { continue }
            day.spots[entry.spot, default: Count()].add(spent)
            live[key]?.counted = time
            counted = true
        }
        return counted
    }

    private func withLive(_ day: Day) -> Day {
        var day = day
        for entry in live.values {
            day.spots[entry.spot, default: Count()].add(entry.process.time.since(entry.counted))
        }
        return day
    }

    private static func read(_ day: String, in folder: URL) -> Day? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("\(day).json")) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Day.self, from: data)
    }

    private static func write(_ day: Day, in folder: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(day) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: folder.appendingPathComponent("\(day.day).json"), options: .atomic)
    }

    private static func prune(_ folder: URL, at date: Date) {
        let first = day(of: Calendar.current.date(byAdding: .day, value: -(keptDays - 1), to: date) ?? date)
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasSuffix(".json") && name < "\(first).json" {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}

private enum OlderKeys: String, CodingKey {
    case uses, powers
}

extension SpotUsage.Count {
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let older = try decoder.container(keyedBy: OlderKeys.self)
        name = try values.decodeIfPresent(String.self, forKey: .name)
        runs = try values.decodeIfPresent(Int.self, forKey: .runs) ?? 0
        failures = try values.decodeIfPresent(Int.self, forKey: .failures) ?? 0
        seconds = try values.decodeIfPresent(TimeInterval.self, forKey: .seconds) ?? 0
        cpu = try values.decodeIfPresent(TimeInterval.self, forKey: .cpu) ?? 0
        read = try values.decodeIfPresent(UInt64.self, forKey: .read) ?? 0
        written = try values.decodeIfPresent(UInt64.self, forKey: .written) ?? 0
        wakeups = try values.decodeIfPresent(UInt64.self, forKey: .wakeups) ?? 0
        calls = try values.decodeIfPresent([String: Int].self, forKey: .calls) ?? older.decodeIfPresent([String: Int].self, forKey: .uses) ?? [:]
        network = try values.decodeIfPresent(Bool.self, forKey: .network) ?? false
        fault = try values.decodeIfPresent(String.self, forKey: .fault)
    }
}

extension SpotUsage.Day {
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let older = try decoder.container(keyedBy: OlderKeys.self)
        day = try values.decode(String.self, forKey: .day)
        spots = try values.decodeIfPresent([String: SpotUsage.Count].self, forKey: .spots) ?? [:]
        uses = try values.decodeIfPresent([SpotUsage.Use].self, forKey: .uses) ?? older.decodeIfPresent([SpotUsage.Use].self, forKey: .powers) ?? []
        told = try values.decodeIfPresent([String].self, forKey: .told) ?? []
    }
}
