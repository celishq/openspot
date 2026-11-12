import CryptoKit
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

    /// Whether the last release names exactly these files, with their bytes and modes. With `built` false, a program or a
    /// view library that the release names and the files lack still matches, since a publish builds it.
    public func names(_ files: [SpotFolder.File], built: Bool = true) -> Bool {
        guard let named = try? last?.files() else { return false }
        let given = Set(files.map { SpotRelease.File(path: $0.path, sha256: AccountKey.hex(Data(CryptoKit.SHA256.hash(data: $0.contents))), size: $0.contents.count, isExecutable: $0.isExecutable) })
        let paths = Set(given.map(\.path))
        let expected = Set(named.filter { built || paths.contains($0.path) || !Self.isBuilt($0.path) })
        return given == expected
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

    private static func isBuilt(_ path: String) -> Bool {
        SwiftProgram.isProgram(URL(fileURLWithPath: path)) || ViewLibrary.isLibrary(path)
    }
}
