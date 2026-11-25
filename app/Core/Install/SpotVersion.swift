import Foundation

public struct SpotVersion: Comparable, Hashable, Sendable {
    static let hashLength = 7
    private static let dateFormat = "yyyy-MM-dd'T'HH:mm'Z'"
    private static let stand = "*"

    public let date: Date
    public let hash: String

    public init(date: Date, hash: String) {
        self.date = Date(timeIntervalSince1970: (date.timeIntervalSince1970 / 60).rounded(.down) * 60)
        self.hash = hash
    }

    public init?(text: String) {
        guard let cut = text.lastIndex(of: "-") else { return nil }
        let hash = String(text[text.index(after: cut)...])
        guard hash.count == Self.hashLength, hash.allSatisfy(\.isHexDigit), let date = Self.formatter().date(from: String(text[..<cut])) else { return nil }
        self.init(date: date, hash: hash)
    }

    public init(of spot: URL) throws {
        let parent = spot.deletingLastPathComponent()
        let root = spot.lastPathComponent
        let files = try Self.shared(in: spot)
        let digest = try SpotDigest(walking: files, in: parent)
        let released = SpotDigest(Array(digest.files).filter { $0.path != "\(root)/\(ReleaseLog.fileName)" })
        let release = ReleaseLog(installed: root, in: parent).flatMap { $0.names(released, built: false) ? $0.last : nil }
        let date = try release.map { Date(timeIntervalSince1970: TimeInterval($0.createdAt)) } ?? files.map { path in
            try FileManager.default.attributesOfItem(atPath: parent.appendingPathComponent(path).path)[.modificationDate] as? Date ?? .distantPast
        }.max() ?? .distantPast
        self.init(date: date, hash: Self.hash(of: digest, root: root))
    }

    public static func hash(of spot: URL) throws -> String {
        let root = spot.lastPathComponent
        return hash(of: try SpotDigest(walking: shared(in: spot), in: spot.deletingLastPathComponent()), root: root)
    }

    public var text: String {
        "\(Self.formatter().string(from: date))-\(hash)"
    }

    public func isNewer(than other: SpotVersion) -> Bool {
        hash != other.hash && date >= other.date
    }

    public func day(now: Date) -> String {
        let calendar = Calendar.current
        let style = Date.FormatStyle(locale: Locale(identifier: "en_GB"), calendar: calendar, timeZone: calendar.timeZone).day().month(.abbreviated)
        return calendar.component(.year, from: date) == calendar.component(.year, from: now) ? date.formatted(style) : date.formatted(style.year())
    }

    public func updatedLine(now: Date) -> String {
        "Updated \(day(now: now))"
    }

    public static func < (one: SpotVersion, other: SpotVersion) -> Bool {
        one.text < other.text
    }

    private static func shared(in spot: URL) throws -> [String] {
        let root = spot.lastPathComponent
        let inner = FileManager.default.enumerator(atPath: spot.path).map { $0.compactMap { $0 as? String } } ?? []
        return inner.filter { path in
            let parts = path.split(separator: "/")
            var isFolder: ObjCBool = false
            return parts.first.map(String.init) != SpotPackage.testsFolder && !parts.contains { $0.hasPrefix(".") } && !SpotDigest.isBuilt(path)
                && FileManager.default.fileExists(atPath: spot.appendingPathComponent(path).path, isDirectory: &isFolder) && !isFolder.boolValue
        }.map { "\(root)/\($0)" }
    }

    private static func hash(of digest: SpotDigest, root: String) -> String {
        let name = SpotID(path: root).name
        let files = digest.files.map { file in
            var parts = file.path.split(separator: "/").map(String.init).dropFirst()
            if parts.count == 1, let only = parts.first, (only as NSString).deletingPathExtension == name {
                let kind = (only as NSString).pathExtension
                parts = [kind.isEmpty ? stand : "\(stand).\(kind)"]
            }
            return SpotDigest.File(path: parts.joined(separator: "/"), sha256: file.sha256, size: file.size, isExecutable: file.isExecutable)
        }
        return String(SpotDigest(files).hash.prefix(hashLength))
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = dateFormat
        return formatter
    }
}
