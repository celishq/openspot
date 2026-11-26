import Foundation
import Synchronization

public final class Timeline: Sendable {
    public static let keptDays = 30
    public static let byteLimit: Int64 = 2 << 30
    public static let cloneLimit: Int64 = 25 << 20
    static let heldText = 16 << 10
    static let forgottenAge: TimeInterval = 600

    public struct Draft: Equatable, Sendable {
        public let kind: TimelineEntry.Kind
        public let values: [String]
        public var title: String?
        public var app: String?
        public var icon: String?
        public var key: String?
        public var at: Date?

        public init(kind: TimelineEntry.Kind, values: [String], title: String? = nil, app: String? = nil, icon: String? = nil, key: String? = nil, at: Date? = nil) {
            self.kind = kind
            self.values = values
            self.title = title
            self.app = app
            self.icon = icon
            self.key = key
            self.at = at
        }
    }

    public struct Query: Equatable, Sendable {
        public var spots: Set<String>?
        public var within: TimeInterval?
        public var text: String?
        public var limit: Int?

        public init(spots: Set<String>? = nil, within: TimeInterval? = nil, text: String? = nil, limit: Int? = nil) {
            self.spots = spots
            self.within = within
            self.text = text
            self.limit = limit
        }
    }

    public struct Choices: Codable, Equatable, Sendable {
        public var keptDays = Timeline.keptDays
        public var pausedUntil: Date?
    }

    private struct Kept {
        var entries: [TimelineEntry] = []
        var folded: [String: String] = [:]
        var isRead = false
        var choices = Choices()
        var readers: [String: Set<String>?] = [:]
    }

    private let folder: URL?
    private let byteLimit: Int64
    private let kept = Mutex(Kept())

    public init(folder: URL?, byteLimit: Int64 = Timeline.byteLimit) {
        self.folder = folder
        self.byteLimit = byteLimit
    }

    public static func standard(environment: [String: String]) -> Timeline {
        let home = environment["HOME"].map { URL(fileURLWithPath: $0) } ?? FileManager.default.homeDirectoryForCurrentUser
        let config = SpotsFolder.ownConfig(environment: environment) ?? SpotsFolder.defaultConfig(home: home)
        return Timeline(folder: config.appendingPathComponent("timeline", isDirectory: true))
    }

    public func keep(days: Int, at now: Date) {
        change(at: now) { $0.keptDays = max(1, days) }
    }

    public func pause(until time: Date?, at now: Date) {
        change(at: now) { $0.pausedUntil = time }
    }

    public func choices() -> Choices {
        kept.withLock { kept in
            read(&kept)
            return kept.choices
        }
    }

    private func change(at now: Date, _ body: (inout Choices) -> Void) {
        kept.withLock { kept in
            read(&kept)
            let before = kept.choices
            body(&kept.choices)
            guard kept.choices != before else { return }
            KeptFile<Choices>(url: folder?.appendingPathComponent("choices.json")).write(kept.choices)
            cut(&kept, at: now)
        }
    }

    public func add(_ draft: Draft, of spot: String, at now: Date) throws -> TimelineEntry? {
        try kept.withLock { kept in
            read(&kept)
            if let until = kept.choices.pausedUntil, now < until { return nil }
            var id = Self.newID()
            while kept.folded[id] != nil { id = Self.newID() }
            let at = draft.at ?? now
            let entry = try make(draft, id: id, spot: spot, at: at)
            if let key = draft.key, let old = kept.entries.first(where: { $0.spot == spot && $0.key == key && $0.forgotten == nil }) {
                remove([old.id], from: &kept)
            }
            kept.entries.append(entry)
            kept.folded[id] = entry.words.folded
            append(entry)
            cut(&kept, at: now)
            return entry
        }
    }

    public func list(_ query: Query, at now: Date) -> [TimelineEntry] {
        kept.withLock { kept in
            read(&kept)
            cut(&kept, at: now)
            let words = (query.text ?? "").folded.split(whereSeparator: \.isWhitespace).map(String.init)
            let since = query.within.map { now.addingTimeInterval(-$0) }
            let folded = kept.folded
            let found = kept.entries.filter { entry in
                entry.forgotten == nil
                    && query.spots.map { $0.contains(entry.spot) } != false
                    && since.map { entry.at >= $0 } != false
                    && words.allSatisfy { folded[entry.id]?.contains($0) == true }
            }
            let sorted = found.sorted { $0.at > $1.at }
            return query.limit.map { Array(sorted.prefix($0)) } ?? sorted
        }
    }

    public func entry(_ id: String) -> TimelineEntry? {
        kept.withLock { kept in
            read(&kept)
            return kept.entries.first { $0.id == id }
        }
    }

    public func forget(_ id: String, at now: Date) -> TimelineEntry? {
        mark(id, forgotten: now)
    }

    public func restore(_ id: String) -> TimelineEntry? {
        mark(id, forgotten: nil)
    }

    public func note(reader: String, of spots: Set<String>?) {
        kept.withLock { _ = $0.readers.updateValue(spots, forKey: reader) }
    }

    public func readers(of spot: String) -> [String] {
        kept.withLock { kept in kept.readers.filter { $0.value.map { $0.contains(spot) } ?? true }.map(\.key).sorted() }
    }

    private func mark(_ id: String, forgotten: Date?) -> TimelineEntry? {
        kept.withLock { kept in
            read(&kept)
            guard let index = kept.entries.firstIndex(where: { $0.id == id }), (kept.entries[index].forgotten == nil) == (forgotten != nil) else { return nil }
            kept.entries[index].forgotten = forgotten
            let entry = kept.entries[index]
            write(day: day(of: entry.at), of: entry.spot, kept.entries)
            return entry
        }
    }

    private func make(_ draft: Draft, id: String, spot: String, at: Date) throws -> TimelineEntry {
        let place = blobs(of: spot, day: day(of: at)).appendingPathComponent(id, isDirectory: true)
        var value = ""
        var textFile: String?
        var files: [TimelineEntry.File] = []
        var bytes: Int64 = 0
        switch draft.kind {
        case .text, .url:
            let text = draft.values.first ?? ""
            bytes = Int64(text.utf8.count)
            if text.utf8.count > Self.heldText, folder != nil {
                let file = place.appendingPathComponent("text.txt")
                try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
                try Data(text.utf8).write(to: file, options: .atomic)
                textFile = file.path
                value = String(decoding: Data(text.utf8).prefix(Self.heldText), as: UTF8.self)
            } else {
                value = text
            }
        case .file, .picture:
            for path in draft.values {
                let file = keep(path, isPicture: draft.kind == .picture, in: place)
                if file.isKept { bytes += Self.size(of: URL(fileURLWithPath: file.path)) }
                files.append(file)
            }
        }
        return TimelineEntry(
            id: id, spot: spot, at: at, kind: draft.kind, value: value, textFile: textFile, files: files, title: draft.title ?? Self.title(of: draft),
            app: draft.app, icon: draft.icon, key: draft.key, bytes: bytes, forgotten: nil
        )
    }

    private func keep(_ path: String, isPicture: Bool, in place: URL) -> TimelineEntry.File {
        let source = URL(fileURLWithPath: path)
        let link = TimelineEntry.File(path: path, original: path, isKept: false)
        guard folder != nil, FileManager.default.fileExists(atPath: path) else { return link }
        try? FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        guard (try? source.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true, Self.size(of: source) <= Self.cloneLimit else { return link }
        guard isPicture || Self.volume(of: source) == Self.volume(of: place) else { return link }
        var target = place.appendingPathComponent(source.lastPathComponent)
        var number = 2
        while FileManager.default.fileExists(atPath: target.path) {
            target = place.appendingPathComponent("\(number) \(source.lastPathComponent)")
            number += 1
        }
        do {
            try FileManager.default.copyItem(at: source, to: target)
            return TimelineEntry.File(path: target.path, original: path, isKept: true)
        } catch {
            return link
        }
    }

    private func read(_ kept: inout Kept) {
        guard !kept.isRead else { return }
        kept.isRead = true
        guard let folder else { return }
        if let choices = KeptFile<Choices>(url: folder.appendingPathComponent("choices.json")).read(or: Choices()) { kept.choices = choices }
        let decoder = JSONDecoder()
        var found: [String: TimelineEntry] = [:]
        for spotFolder in (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? [] {
            for file in (try? FileManager.default.contentsOfDirectory(at: spotFolder, includingPropertiesForKeys: nil)) ?? [] where file.pathExtension == "jsonl" {
                guard let data = try? Data(contentsOf: file) else { continue }
                for line in data.split(separator: UInt8(ascii: "\n")) {
                    guard let entry = try? decoder.decode(TimelineEntry.self, from: line) else { continue }
                    found[entry.id] = entry
                }
            }
        }
        kept.entries = found.values.sorted { $0.at < $1.at }
        for entry in kept.entries { kept.folded[entry.id] = entry.words.folded }
    }

    private func cut(_ kept: inout Kept, at now: Date) {
        let oldest = day(of: now.addingTimeInterval(-Double(kept.choices.keptDays - 1) * 86_400))
        let old = kept.entries.filter { day(of: $0.at) < oldest || $0.forgotten.map { now.timeIntervalSince($0) > Self.forgottenAge } == true }
        var gone = Set(old.map(\.id))
        var bytes = kept.entries.reduce(Int64(0)) { $0 + (gone.contains($1.id) ? 0 : $1.bytes) }
        for entry in kept.entries.sorted(by: { $0.at < $1.at }) where bytes > byteLimit && !gone.contains(entry.id) {
            gone.insert(entry.id)
            bytes -= entry.bytes
        }
        if !gone.isEmpty { remove(gone, from: &kept) }
    }

    private func remove(_ ids: some Collection<String>, from kept: inout Kept) {
        let ids = Set(ids)
        let gone = kept.entries.filter { ids.contains($0.id) }
        kept.entries.removeAll { ids.contains($0.id) }
        for id in ids { kept.folded[id] = nil }
        for entry in gone {
            try? FileManager.default.removeItem(at: blobs(of: entry.spot, day: day(of: entry.at)).appendingPathComponent(entry.id, isDirectory: true))
        }
        var days: Set<[String]> = []
        for entry in gone where days.insert([entry.spot, day(of: entry.at)]).inserted {
            write(day: day(of: entry.at), of: entry.spot, kept.entries)
        }
    }

    private func append(_ entry: TimelineEntry) {
        guard let file = file(of: entry.spot, day: day(of: entry.at)), let line = try? JSONEncoder().encode(entry) else { return }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let handle = FileHandle(forWritingAtPath: file.path) else {
            try? (line + Data("\n".utf8)).write(to: file, options: .atomic)
            return
        }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: line + Data("\n".utf8))
    }

    private func write(day: String, of spot: String, _ entries: [TimelineEntry]) {
        guard let file = file(of: spot, day: day) else { return }
        let lines = entries.filter { $0.spot == spot && self.day(of: $0.at) == day }.compactMap { try? JSONEncoder().encode($0) }
        guard !lines.isEmpty else {
            try? FileManager.default.removeItem(at: file)
            try? FileManager.default.removeItem(at: blobs(of: spot, day: day))
            return
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? lines.map { $0 + Data("\n".utf8) }.reduce(Data(), +).write(to: file, options: .atomic)
    }

    private func file(of spot: String, day: String) -> URL? {
        folder?.appendingPathComponent(Self.folderName(of: spot), isDirectory: true).appendingPathComponent("\(day).jsonl")
    }

    private func blobs(of spot: String, day: String) -> URL {
        (folder ?? FileManager.default.temporaryDirectory).appendingPathComponent(Self.folderName(of: spot), isDirectory: true).appendingPathComponent(day, isDirectory: true)
    }

    private func day(of date: Date) -> String {
        let parts = Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    private static func newID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).lowercased()
    }

    private static func folderName(of spot: String) -> String {
        spot.replacingOccurrences(of: "/", with: "%2F")
    }

    private static func title(of draft: Draft) -> String {
        switch draft.kind {
        case .text:
            let line = (draft.values.first ?? "").split(whereSeparator: \.isNewline).first { !$0.allSatisfy(\.isWhitespace) } ?? ""
            return String(line.trimmingCharacters(in: .whitespaces).prefix(200))
        case .url:
            return draft.values.first ?? ""
        case .file, .picture:
            let name = draft.values.first.map { ($0 as NSString).lastPathComponent } ?? ""
            return draft.values.count > 1 ? "\(name) and \(draft.values.count - 1) more" : name
        }
    }

    private static func size(of url: URL) -> Int64 {
        Int64((try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }

    private static func volume(of url: URL) -> NSObject? {
        (try? url.resourceValues(forKeys: [.volumeIdentifierKey]))?.volumeIdentifier as? NSObject
    }
}
