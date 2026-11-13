import Foundation

/// The `releases.jsonl` of a spot folder: each signed release of the spot, the oldest first, one event a line. Each
/// release names the one before it, so the log shows who released what, in order.
public struct ReleaseLog: Equatable, Sendable {
    public static let fileName = "releases.jsonl"

    public let releases: [SpotRelease]

    public init(releases: [SpotRelease]) {
        self.releases = releases
    }

    /// Reads a log, and throws a fault for a line that is no event, a signature that does not match, or a release that does
    /// not name the one before it.
    public init(text: String) throws {
        var releases: [SpotRelease] = []
        for line in text.split(separator: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            let release = try SpotRelease(line: String(line))
            guard release.kind == SpotRelease.kind, release.isAuthentic, release.address != nil, release.version != nil else {
                throw SpotError.fault("\(Self.fileName) holds a release whose signature does not match.")
            }
            guard release.previous == releases.last?.id else {
                throw SpotError.fault("\(Self.fileName) holds a release that does not follow the one before it.")
            }
            releases.append(release)
        }
        self.releases = releases
    }

    /// The log of the copy of a spot folder that a spots folder holds, when it has one that checks.
    public init?(installed root: String, in folder: URL) {
        let file = folder.appendingPathComponent(root).appendingPathComponent(Self.fileName)
        guard let text = try? String(contentsOf: file, encoding: .utf8), let log = try? ReleaseLog(text: text) else { return nil }
        self = log
    }

    /// The lines that a review shows of the last release over the log of the installed copy. A new install shows nothing of
    /// its signer. An update says its version, and a version that another key signed, or that no key signed over a signed
    /// copy, says so first.
    public func review(over installed: ReleaseLog?) -> (lines: [String], isOtherKey: Bool) {
        guard let mine = installed?.last else { return ([], false) }
        guard let theirs = last, theirs.publicKey == mine.publicKey else {
            return (["Another key signed this version than the one you have. Add it only if you trust the sender."], true)
        }
        return theirs.version.map { (["Update to version \($0)"], false) } ?? ([], false)
    }

    public var last: SpotRelease? {
        releases.last
    }

    public var text: String {
        releases.map { $0.line + "\n" }.joined()
    }

    /// Whether the last release names exactly the files of this manifest. With `built` false, a program or a view library
    /// that the release names and the manifest lacks still matches, since a publish builds it.
    public func names(_ manifest: SpotManifest, built: Bool = true) -> Bool {
        guard let named = try? last?.manifest() else { return false }
        guard !built else { return named == manifest }
        let paths = Set(manifest.files.map(\.path))
        return SpotManifest(Array(named.files).filter { paths.contains($0.path) || !SpotManifest.isBuilt($0.path) }) == manifest
    }

    /// This log with a release of these files after its last one: the next version of its address when this key signed the
    /// last one, and else version 1 of a new address, since a changed copy of another person's spot is a new spot.
    public func signing(_ files: [SpotPackage.File], readme: String, by key: AccountKey, at date: Date = Date()) throws -> ReleaseLog {
        let isOwn = last?.publicKey == key.publicKey
        let address = isOwn ? last?.address : nil
        let version = isOwn ? (last?.version ?? 0) + 1 : 1
        let release = try SpotRelease.sign(
            files, address: address ?? Self.newAddress(), version: version, previous: last?.id, readme: readme, by: key, at: date
        )
        return ReleaseLog(releases: releases + [release])
    }

    private static func newAddress() -> String {
        UUID().uuidString.lowercased().replacingOccurrences(of: "-", with: "")
    }
}
