import Foundation

/// What each spot cost and used, one day at a time (G1, Z10): its runs and failures, their time, the CPU time, the disk
/// bytes and the wakeups of its processes, each use of a power and its last fault, with a short log of the uses of a
/// power. Today lives in memory and goes to `<day>.json` in its folder at most once a pause, never on each call (G5). A
/// start reads today's file again, and drops each file older than 90 days.
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
        /// The count of each use of a power, by its name, such as `screen.shot`.
        public var uses: [String: Int] = [:]
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
            sum.uses.merge(older.uses, uniquingKeysWith: +)
            sum.network = network || older.network
            sum.fault = fault ?? older.fault
            return sum
        }
    }

    /// One use of a power by a spot.
    public struct Power: Codable, Equatable, Sendable {
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
        /// The newest uses of a power, the oldest first.
        public var powers: [Power] = []
        /// Each spot and use that the person was told of this day, as `<spot> <use>` (Z4).
        var told: [String] = []
    }

    static let keptDays = 90
    private static let powerLimit = 100

    private let folder: URL?
    private let pause: TimeInterval
    private let lock = NSLock()
    private var today: Day
    private var isDirty = false
    private var isWaiting = false
    /// Each process that has not ended, with the ID of its spot.
    private var live: [ObjectIdentifier: (spot: String, process: ScriptProcess)] = [:]

    /// Starts the day of `date` from its file in `folder`, and drops each file older than 90 days. With no folder it keeps
    /// nothing on the disk. `pause` is the most time that a change waits for its write.
    public init(folder: URL? = nil, at date: Date = Date(), pause: TimeInterval = 5) {
        self.folder = folder
        self.pause = pause
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
        lock.withLock { live[key] = (spot, process) }
        process.onExit { [weak self] time in
            guard let self, let spot = lock.withLock({ live.removeValue(forKey: key)?.spot }) else { return }
            add(time, to: spot)
        }
    }

    /// Adds the time of an ended process to a spot, on the day that runs.
    func add(_ time: ProcessTime, to spot: String) {
        change { $0.spots[spot, default: Count()].add(time) }
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

    /// Keeps the fault that the person was told, as the last of this spot.
    func failed(_ spot: Spot, fault: String, at date: Date) {
        change(at: date) { day in
            day.spots[spot.id, default: Count()].name = spot.name
            day.spots[spot.id, default: Count()].fault = fault
        }
    }

    /// Counts and logs a use of a power by a spot, and returns whether to tell the person: its first use of the day that its
    /// header does not name (Z4).
    func used(_ power: SpotPower, by caller: CallerTokens.Caller, at date: Date) -> Bool {
        let declared = caller.uses.contains(power.use)
        var tells = false
        change(at: date) { day in
            day.spots[caller.id, default: Count()].name = caller.name
            day.spots[caller.id, default: Count()].uses[power.name, default: 0] += 1
            day.spots[caller.id, default: Count()].network = caller.uses.contains(.network)
            day.powers = Array((day.powers + [Power(time: date, spot: caller.id, call: power.name, declared: declared)]).suffix(Self.powerLimit))
            let told = "\(caller.id) \(power.use.rawValue)"
            if !declared, !day.told.contains(told) {
                day.told.append(told)
                tells = true
            }
        }
        return tells
    }

    /// Writes today's file now when it changed since the last write.
    public func flush() {
        guard let folder else { return }
        let day: Day? = lock.withLock {
            isWaiting = false
            guard isDirty else { return nil }
            isDirty = false
            return today
        }
        if let day { Self.write(day, in: folder) }
    }

    /// The day of a date in the time zone of the Mac, such as `2026-11-11`.
    static func day(of date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Changes the day that runs, or with a date first moves to its day, and asks for a write after the pause.
    private func change(at date: Date? = nil, _ work: (inout Day) -> Void) {
        let (ended, waits): (Day?, Bool) = lock.withLock {
            var ended: Day?
            if let date, Self.day(of: date) != today.day {
                if isDirty { ended = today }
                today = folder.flatMap { Self.read(Self.day(of: date), in: $0) } ?? Day(day: Self.day(of: date))
            }
            work(&today)
            isDirty = true
            defer { isWaiting = true }
            return (ended, !isWaiting)
        }
        guard let folder else { return }
        if let ended {
            Self.write(ended, in: folder)
            if let date { Self.prune(folder, at: date) }
        }
        if waits {
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + pause) { [weak self] in self?.flush() }
        }
    }

    /// The day with the time so far of each process that runs.
    private func withLive(_ day: Day) -> Day {
        var day = day
        for (spot, process) in live.values {
            day.spots[spot, default: Count()].add(process.time)
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
