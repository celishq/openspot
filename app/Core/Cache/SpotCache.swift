import Foundation
import Synchronization

public final class SpotCache: Sendable {
    public static let byteLimit = 16 << 20
    public static let memoryLimit = 16 << 20

    public struct Entry: Equatable, Sendable {
        public let value: String
        public let saved: Date
    }

    public enum Failure: Error, Equatable {
        case badName(String)
        case full(spot: String)
    }

    private let folder: URL
    private let kept = Mutex<(entries: [String: Entry], bytes: Int)>(([:], 0))
    private let pressure = Mutex<(any DispatchSourceMemoryPressure)?>(nil)
    private let writing = NSLock()

    public init(folder: URL) {
        self.folder = folder
    }

    private static let shared = Mutex<[URL: SpotCache]>([:])

    public static func standard(environment: [String: String], home: URL) -> SpotCache {
        let own = SpotsFolder.ownConfig(environment: environment)
        let folder = own?.appendingPathComponent("cache") ?? home.appendingPathComponent("Library/Caches/openspot/spots")
        return shared.withLock { caches in
            if let cache = caches[folder] { return cache }
            let cache = SpotCache(folder: folder)
            caches[folder] = cache
            return cache
        }
    }

    public static func isName(_ name: String) -> Bool {
        !name.isEmpty && name.first != "." && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "-_.".contains($0)) }
    }

    public func read(_ name: String, of spot: String) -> Entry? {
        let key = Self.key(name, of: spot)
        if let entry = kept.withLock({ $0.entries[key] }) { return entry }
        guard Self.isName(name) else { return nil }
        writing.lock()
        defer { writing.unlock() }
        if let entry = kept.withLock({ $0.entries[key] }) { return entry }
        let file = place(name, of: spot)
        guard let data = try? Data(contentsOf: file),
              let saved = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return nil }
        let entry = Entry(value: String(decoding: data, as: UTF8.self), saved: saved)
        remember(entry, as: key)
        return entry
    }

    @discardableResult
    public func keep(_ value: String, as name: String, of spot: String, at date: Date = Date()) throws(Failure) -> Bool {
        guard Self.isName(name) else { throw .badName(name) }
        let isChanged = read(name, of: spot)?.value != value
        writing.lock()
        defer { writing.unlock() }
        let file = place(name, of: spot)
        let data = Data(value.utf8)
        let others = bytes(of: spot) - ((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        guard others + data.count <= Self.byteLimit else { throw .full(spot: spot) }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: file.path)
        } catch {
            throw .full(spot: spot)
        }
        remember(Entry(value: value, saved: date), as: Self.key(name, of: spot))
        return isChanged
    }

    public func dropMemory() {
        kept.withLock { $0 = ([:], 0) }
    }

    private func remember(_ entry: Entry, as key: String) {
        kept.withLock { kept in
            kept.bytes -= kept.entries[key].map { $0.value.utf8.count } ?? 0
            if kept.bytes + entry.value.utf8.count > Self.memoryLimit { kept = ([:], 0) }
            kept.entries[key] = entry
            kept.bytes += entry.value.utf8.count
        }
    }

    public func listenForMemoryPressure() {
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        source.setEventHandler { [weak self] in self?.dropMemory() }
        source.resume()
        pressure.withLock { $0 = source }
    }

    private func place(_ name: String, of spot: String) -> URL {
        folder.appendingPathComponent(spot).appendingPathComponent(name)
    }

    private func bytes(of spot: String) -> Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder.appendingPathComponent(spot), includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    private static func key(_ name: String, of spot: String) -> String {
        "\(spot)/\(name)"
    }
}
