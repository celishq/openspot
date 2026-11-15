import Foundation
import Synchronization

public final class KeptScan: Sendable {
    private struct Kept: Sendable {
        let states: [String: [Int]]
        let entries: [SpotLoad.Entry]
    }

    public static let shared = KeptScan()
    private static let limit = 1024

    private let kept = Mutex<[String: Kept]>([:])

    public init() {}

    public func load(_ folder: SpotsFolder, wrapping: Bool = false) -> SpotLoad {
        if wrapping { try? SpotsFolder.wrap(folder.url) }
        var stamp: [String: [Int]] = [:]
        var entries: [SpotLoad.Entry] = []
        var loose: [ScanResult.Refusal] = []
        let own = try? Self.sorted(in: folder.url)
        for file in own ?? [] {
            stamp[file.path] = Self.state(of: file.path)
            guard SpotsFolder.isScript(file) else { continue }
            loose.append(ScanResult.Refusal(file: file.lastPathComponent, reason: SpotsFolder.looseReason(file, in: folder.url)))
        }
        entries += read(Self.spotFolders(in: own ?? []), origin: .own, into: &stamp)
        let core = folder.core.map { Self.spotFolders(in: (try? Self.sorted(in: $0)) ?? []) } ?? []
        let app = core.filter { $0.lastPathComponent == SpotsFolder.appName }
        entries += read(core.filter { !app.contains($0) }, origin: .core, into: &stamp)
        entries += read(app, origin: .app, into: &stamp)
        let failure = own == nil && folder.core == nil ? "Openspot cannot read the folder \(folder.url.path)." : nil
        return SpotLoad(entries: entries, loose: loose, failure: failure, stamp: stamp, hasAppSpots: !app.isEmpty)
    }

    private func read(_ folders: [URL], origin: SpotLoad.Origin, into stamp: inout [String: [Int]]) -> [SpotLoad.Entry] {
        folders.flatMap { folder in
            var states = [folder.path: Self.state(of: folder.path)]
            let files = ((try? Self.sorted(in: folder)) ?? []).filter { file in
                let state = Self.state(of: file.path)
                states[file.path] = state
                return state.first != Int(S_IFDIR)
            }
            stamp.merge(states) { _, new in new }
            let key = "\(origin) \(folder.path)"
            if let kept = kept.withLock({ $0[key] }), kept.states == states { return kept.entries }
            let entries = files.map { Self.entry(of: $0, origin: origin) }
            kept.withLock {
                if $0.count >= Self.limit { $0.removeAll() }
                $0[key] = Kept(states: states, entries: entries)
            }
            return entries
        }
    }

    private static func entry(of file: URL, origin: SpotLoad.Origin) -> SpotLoad.Entry {
        let id = SpotID(file: file).description
        let added = origin == .own ? (try? file.resourceValues(forKeys: [.creationDateKey]).creationDate) : nil
        ScanWork.meter?.parse()
        do {
            let parsed = SpotLoad.Entry(id: id, file: file, origin: origin, spots: try SpotFile(file: file, id: id)?.spots, refusal: nil, added: added)
            return SpotLoad.Entry(id: id, file: file, origin: origin, spots: parsed.spots?.map(parsed.placed), refusal: nil, added: added)
        } catch {
            let reason = (error as? SpotError)?.reason ?? String(describing: error)
            return SpotLoad.Entry(id: id, file: file, origin: origin, spots: nil, refusal: reason, added: added)
        }
    }

    private static func spotFolders(in entries: [URL]) -> [URL] {
        entries.filter { $0.pathExtension == SpotPackage.fileExtension && isFolder($0) }
    }

    private static func isFolder(_ url: URL) -> Bool {
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isFolder) && isFolder.boolValue
    }

    private static func state(of path: String) -> [Int] {
        ScanWork.meter?.stat()
        var info = stat()
        guard stat(path, &info) == 0 else { return [] }
        return [
            Int(info.st_mode & S_IFMT), Int(info.st_dev), Int(info.st_ino), Int(info.st_mode), Int(info.st_size),
            info.st_ctimespec.tv_sec, info.st_ctimespec.tv_nsec, info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec
        ]
    }

    private static func sorted(in folder: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { !$0.hasPrefix(".") }.sorted()
            .map { folder.appendingPathComponent($0) }
    }
}
