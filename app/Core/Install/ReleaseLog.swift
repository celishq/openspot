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
    public func signing(_ files: [SpotFolder.File], readme: String, by key: AccountKey, at date: Date = Date()) throws -> ReleaseLog {
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
