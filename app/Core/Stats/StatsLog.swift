import Foundation

public final class StatsLog: @unchecked Sendable {
    public struct ViewTime: Codable, Equatable, Sendable {
        public var bodies = 0
        public var seconds: TimeInterval = 0

        func adding(_ other: ViewTime?) -> ViewTime {
            ViewTime(bodies: bodies + (other?.bodies ?? 0), seconds: seconds + (other?.seconds ?? 0))
        }
    }

    public enum Failure: String, Codable, Sendable {
        case timeout
        case exit
        case output

        var words: String {
            switch self {
            case .timeout: "timed out"
            case .exit: "stopped with an error"
            case .output: "printed what Openspot cannot read"
            }
        }

        public init(_ error: Error) {
            self = switch error as? SpotError {
            case .timedOut: .timeout
            case .tooLarge, .badState, .badForm, .badMetric: .output
            default: .exit
            }
        }
    }

    public struct Use: Codable, Equatable, Sendable {
        public let time: Date
        public let spot: String
        public let call: String
        public let declared: Bool
    }

    public struct Version: Codable, Equatable, Sendable {
        public let first: Date?
        public var count = Count()
    }

    public struct Day: Codable, Equatable, Sendable {
        static let unknownVersion = "-"

        public let day: String
        public var versions: [String: [String: Version]] = [:]
        public var uses: [Use] = []
        public var searches: [String: Int] = [:]
        public var countsActs = true
        var told: [String] = []

        public var spots: [String: Count] {
            versions.mapValues { kept in
                kept.values.sorted { ($0.first ?? .distantPast) > ($1.first ?? .distantPast) }.map(\.count).reduce(nil) { sum, count in sum?.adding(count) ?? count } ?? Count()
            }
        }

        mutating func change(_ id: String, version: String?, at date: Date, _ work: (inout Count) -> Void) {
            work(&versions[id, default: [:]][version ?? Self.unknownVersion, default: Version(first: date)].count)
        }
    }

    static let keptDays = 90
    private static let useLimit = 100
    static let searchLimit = 50

    private let folder: URL?
    private let pause: TimeInterval
    private let lock = NSLock()
    private let writes = DispatchQueue(label: "dev.openspot.stats")
    private var today: Day
    private var isDirty = false
    private var isWaiting = false
    private var views: [String: (id: String, name: String)] = [:]
    private var spotVersions: [String: String] = [:]
    private var isShown = false
    private var live: [ObjectIdentifier: (spot: String, process: ScriptProcess, counted: ProcessTime)] = [:]
    let now: () -> Date

    public init(folder: URL? = nil, at date: Date = Date(), pause: TimeInterval = 60, now: @escaping () -> Date = { Date() }) {
        self.folder = folder
        self.pause = pause
        self.now = now
        let day = Self.day(of: date)
        today = folder.flatMap { Self.read(day, in: $0) } ?? Day(day: day)
        today.countsActs = true
        if let folder { Self.prune(folder, at: date) }
    }

    public var counts: [String: Count] {
        lock.withLock { withLive(today).spots }
    }

    public func days(_ count: Int, at date: Date) -> [Day] {
        writes.sync {}
        let now = lock.withLock { withLive(today) }
        return Self.days(count, at: date, today: now, in: folder)
    }

    public static func days(_ count: Int, at date: Date, today: Day? = nil, in folder: URL?) -> [Day] {
        (0..<max(count, 1)).compactMap { back in
            let name = day(of: Calendar.current.date(byAdding: .day, value: -back, to: date) ?? date)
            if let today, today.day == name { return today }
            return folder.flatMap { read(name, in: $0) } ?? Day(day: name, countsActs: back == 0 && today != nil)
        }
    }

    @concurrent
    static func days(_ count: Int, runs: SpotRuns?, environment: [String: String]) async -> [Day] {
        guard let runs else {
            return days(count, at: Date(), in: AppPlaces(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser, defaults: .standard).stats)
        }
        let now = await MainActor.run { runs.now() }
        return runs.usage.days(count, at: now)
    }

    func take(views spots: [Spot]) {
        let views = Dictionary(spots.compactMap { spot in spot.view.map { ($0, (id: spot.id, name: spot.name)) } }) { first, _ in first }
        lock.withLock { self.views = views }
    }

    func take(versions: [String: String]) {
        lock.withLock { spotVersions = versions }
    }

    public func drew(view source: String, seconds: TimeInterval) {
        let date = now()
        change { day in
            guard let spot = views[source] else { return }
            day.change(spot.id, version: spotVersions[spot.id], at: date) { count in
                count.name = spot.name
                count.view = ViewTime(bodies: 1, seconds: seconds).adding(count.view)
            }
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
        change(at: date) { $0.change(spot, version: spotVersions[spot], at: date) { $0.add(time, hidden: !isShown) } }
    }

    public func panel(shown: Bool) {
        lock.withLock {
            if countLive(into: &today) { isDirty = true }
            isShown = shown
        }
    }

    func acted(_ spot: Spot, at date: Date) {
        change(spot, at: date) { $0.act(at: date) }
    }

    func called(_ spot: Spot, _ outcome: CallOutcome, at date: Date) {
        change(spot, at: date) { $0.call(outcome, network: spot.uses.contains(.network), at: date) }
    }

    func ran(_ spot: Spot, by caller: String, _ outcome: CallOutcome, at date: Date) {
        change(spot, at: date) { count in
            count.call(outcome, network: spot.uses.contains(.network), at: date)
            count.callers[caller, default: 0] += 1
        }
    }

    func failedRun(_ spot: Spot, failure: Failure, at date: Date) {
        change(spot, at: date) { $0.failures.add(failure, at: date) }
    }

    func failed(_ spot: Spot, fault: String, at date: Date) {
        change(spot, at: date) { count in
            count.fault = fault
            count.failures.last = date
        }
    }

    func used(_ call: SpotUseCall, by caller: Spot, at date: Date) -> Bool {
        let declared = caller.uses.contains(call.use)
        var tells = false
        change(at: date) { day in
            day.change(caller.id, version: spotVersions[caller.id], at: date) { count in
                count.name = caller.name
                count.calls[call.name, default: 0] += 1
                count.network = caller.uses.contains(.network)
            }
            if !declared { day.uses = Array((day.uses + [Use(time: date, spot: caller.id, call: call.name, declared: declared)]).suffix(Self.useLimit)) }
            let told = "\(caller.id) \(call.use.rawValue)"
            if !declared, !day.told.contains(told) {
                day.told.append(told)
                tells = true
            }
        }
        return tells
    }

    func missed(_ search: String, at date: Date) {
        change(at: date) { day in
            guard day.searches[search] != nil || day.searches.count < Self.searchLimit else { return }
            day.searches[search, default: 0] += 1
        }
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

    private func change(_ spot: Spot, at date: Date, _ work: (inout Count) -> Void) {
        change(at: date) { day in
            day.change(spot.id, version: spotVersions[spot.id], at: date) { count in
                count.name = spot.name
                work(&count)
            }
        }
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
        today.countsActs = true
        return ended
    }

    private func countLive(into day: inout Day) -> Bool {
        var counted = false
        for (key, entry) in live {
            let time = entry.process.time
            let spent = time.since(entry.counted)
            guard spent != .zero else { continue }
            day.change(entry.spot, version: spotVersions[entry.spot], at: now()) { $0.add(spent, hidden: !isShown) }
            live[key]?.counted = time
            counted = true
        }
        return counted
    }

    private func withLive(_ day: Day) -> Day {
        var day = day
        for entry in live.values {
            day.change(entry.spot, version: spotVersions[entry.spot], at: now()) { $0.add(entry.process.time.since(entry.counted), hidden: !isShown) }
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

extension StatsLog.Day {
    private enum KeptKeys: String, CodingKey {
        case spots
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        day = try values.decode(String.self, forKey: .day)
        let kept = try decoder.container(keyedBy: KeptKeys.self).decodeIfPresent([String: StatsLog.Count].self, forKey: .spots) ?? [:]
        versions = try values.decodeIfPresent([String: [String: StatsLog.Version]].self, forKey: .versions)
            ?? kept.mapValues { [Self.unknownVersion: StatsLog.Version(first: nil, count: $0)] }
        uses = try values.decodeIfPresent([StatsLog.Use].self, forKey: .uses) ?? []
        searches = try values.decodeIfPresent([String: Int].self, forKey: .searches) ?? [:]
        countsActs = try values.decodeIfPresent(Bool.self, forKey: .countsActs) ?? false
        told = try values.decodeIfPresent([String].self, forKey: .told) ?? []
    }
}
