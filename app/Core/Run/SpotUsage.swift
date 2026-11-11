import Foundation

/// What each spot cost and used, one day at a time (G1, Z10): its runs and failures, their time, the CPU time, the disk
/// bytes and the wakeups of its processes, the count of each call that needs a use and its last fault, with a short log of
/// those calls. Today lives in memory and goes to `<day>.json` in its folder at most once a pause, never on each call (G5). A
/// process that runs counts its time since the last reading at each change of day and each flush, so that each day gets
/// the time spent on it. A start reads today's file again, and drops each file older than 90 days.
public final class SpotUsage: @unchecked Sendable {
    /// The count of one spot on one day.
    public struct Count: Codable, Equatable, Sendable {
        public var name: String?
        public var runs = 0
        public var failures = 0
        /// The wall time of its calls, in seconds.
        public var seconds: TimeInterval = 0
        /// The CPU time of its processes, in seconds.
        public var cpu: TimeInterval = 0
        public var read: UInt64 = 0
        public var written: UInt64 = 0
        public var wakeups: UInt64 = 0
        /// The count of each call that needs a use, by its noun and verb, such as `screen.shot`.
        public var calls: [String: Int] = [:]
        /// Whether its header names `network`, which no count can show.
        public var network = false
        public var fault: String?

        mutating func add(_ time: ProcessTime) {
            cpu += time.cpu
            read += time.read
            written += time.written
            wakeups += time.wakeups
        }

        /// This count with a count of an older day added, which keeps the newer name and fault.
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

    /// One call of a spot that needs a use.
    public struct Use: Codable, Equatable, Sendable {
        public let time: Date
        public let spot: String
        /// The noun and the verb of the call, such as `app.quit`.
        public let call: String
        /// Whether the spot's header names the use.
        public let declared: Bool
    }

    /// The counts of one day, as its file keeps them.
    public struct Day: Codable, Equatable, Sendable {
        /// The day, such as `2026-11-11`.
        public let day: String
        public var spots: [String: Count] = [:]
        /// The newest calls that need a use, the oldest first.
        public var uses: [Use] = []
        /// Each spot and use that the person was told of this day, as `<spot> <use>` (Z4).
        var told: [String] = []
    }

    static let keptDays = 90
    private static let useLimit = 100

    private let folder: URL?
    private let pause: TimeInterval
    private let lock = NSLock()
    /// The one queue of each write, so that a newer copy of a day never lands before an older one.
    private let writes = DispatchQueue(label: "dev.openspot.stats")
    private var today: Day
    private var isDirty = false
    private var isWaiting = false
    /// Each process that has not ended, with the ID of its spot and its time that a day already counts.
    private var live: [ObjectIdentifier: (spot: String, process: ScriptProcess, counted: ProcessTime)] = [:]
    /// The clock of the days.
    let now: () -> Date

    /// Starts the day of `date` from its file in `folder`, and drops each file older than 90 days. With no folder it keeps
    /// nothing on the disk. `pause` is the most time that a change waits for its write.
    public init(folder: URL? = nil, at date: Date = Date(), pause: TimeInterval = 5, now: @escaping () -> Date = { Date() }) {
        self.folder = folder
        self.pause = pause
        self.now = now
        let day = Self.day(of: date)
        today = folder.flatMap { Self.read(day, in: $0) } ?? Day(day: day)
        if let folder { Self.prune(folder, at: date) }
    }

    /// Today's count of each spot by its ID, with the time so far of each process that runs.
    public var counts: [String: Count] {
        lock.withLock { withLive(today).spots }
    }

    /// The counts of the last `count` days through the day of `date`, the newest first: today live, and each older day from
    /// its file.
    public func days(_ count: Int, at date: Date) -> [Day] {
        let now = lock.withLock { Self.day(of: date) == today.day ? withLive(today) : nil }
        return Self.days(count, at: date, today: now, in: folder)
    }

    /// The counts of the last `count` days through the day of `date` in a folder, the newest first, with `today` in place
    /// of the file of its day.
    public static func days(_ count: Int, at date: Date, today: Day? = nil, in folder: URL?) -> [Day] {
        (0..<max(count, 1)).compactMap { back in
            let name = day(of: Calendar.current.date(byAdding: .day, value: -back, to: date) ?? date)
            if let today, today.day == name { return today }
            return folder.flatMap { read(name, in: $0) }
        }
    }

    /// Counts the time of a process of a spot, while it runs and once it ends. Call it before the process starts.
    func track(_ process: ScriptProcess, of spot: String) {
        let key = ObjectIdentifier(process)
        lock.withLock { live[key] = (spot, process, .zero) }
        process.onExit { [weak self] time in
            guard let self, let ended = lock.withLock({ live.removeValue(forKey: key) }) else { return }
            add(time.since(ended.counted), to: ended.spot, at: now())
        }
    }

    /// Adds time of a spot on the day of `date`.
    func add(_ time: ProcessTime, to spot: String, at date: Date) {
        change(at: date) { $0.spots[spot, default: Count()].add(time) }
    }

    /// Counts a call that ended after this many seconds, and whether it failed.
    func called(_ spot: Spot, seconds: TimeInterval, isFailure: Bool, at date: Date) {
        change(at: date) { day in
            day.spots[spot.id, default: Count()].name = spot.name
            day.spots[spot.id, default: Count()].runs += 1
            day.spots[spot.id, default: Count()].seconds += seconds
            if isFailure { day.spots[spot.id, default: Count()].failures += 1 }
            day.spots[spot.id, default: Count()].network = spot.uses.contains(.network)
        }
    }

    /// Counts a failure of a spot that no ended call counts, such as of a process that stays.
    func failedRun(_ spot: Spot, at date: Date) {
        change(at: date) { day in
            day.spots[spot.id, default: Count()].name = spot.name
            day.spots[spot.id, default: Count()].failures += 1
        }
    }

    /// Keeps the fault that the person was told, as the last of this spot.
    func failed(_ spot: Spot, fault: String, at date: Date) {
        change(at: date) { day in
            day.spots[spot.id, default: Count()].name = spot.name
            day.spots[spot.id, default: Count()].fault = fault
        }
    }

    /// Counts and logs a spot's call that needs a use, and returns whether to tell the person: its first such call of the
    /// day whose use its header does not name (Z4).
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

    /// Counts the time of each process that runs since the last reading, on the day that runs or that the clock left, and
    /// writes today's file now when it changed since the last write.
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

    /// The day of a date in the time zone of the Mac, such as `2026-11-11`.
    static func day(of date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Changes the day that runs, or with a date first moves to its day, and asks for a write after the pause.
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
            writes.sync { Self.write(ended, in: folder) }
            if let date { Self.prune(folder, at: date) }
        }
        if waits {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + pause) { [weak self] in self?.flush() }
        }
    }

    /// Moves to the day of a date, after the time so far of each process that runs goes to the day that ends, and returns
    /// that day when it changed. Call it with the lock held.
    private func roll(to date: Date) -> Day? {
        guard Self.day(of: date) != today.day else { return nil }
        if countLive(into: &today) { isDirty = true }
        let ended = isDirty ? today : nil
        today = folder.flatMap { Self.read(Self.day(of: date), in: $0) } ?? Day(day: Self.day(of: date))
        return ended
    }

    /// Adds the time of each process that runs since its last reading to a day, and moves each reading. Returns whether
    /// any time came. Call it with the lock held.
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

    /// The day with the time of each process that runs since its last reading.
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

    /// Drops each file of a day older than the 90 days through the day of `date`.
    private static func prune(_ folder: URL, at date: Date) {
        let first = day(of: Calendar.current.date(byAdding: .day, value: -(keptDays - 1), to: date) ?? date)
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasSuffix(".json") && name < "\(first).json" {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        }
    }
}

/// The keys of a day file of an older form, which named a call that needs a use a power.
private enum OlderKeys: String, CodingKey {
    case uses, powers
}

extension SpotUsage.Count {
    /// Reads a count, with each key that a file of an older form lacks at its default, and its calls under their older key.
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
    /// Reads a day, with each key that a file of an older form lacks at its default, and its uses under their older key.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let older = try decoder.container(keyedBy: OlderKeys.self)
        day = try values.decode(String.self, forKey: .day)
        spots = try values.decodeIfPresent([String: SpotUsage.Count].self, forKey: .spots) ?? [:]
        uses = try values.decodeIfPresent([SpotUsage.Use].self, forKey: .uses) ?? older.decodeIfPresent([SpotUsage.Use].self, forKey: .powers) ?? []
        told = try values.decodeIfPresent([String].self, forKey: .told) ?? []
    }
}
