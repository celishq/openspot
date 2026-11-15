import CryptoKit
import Foundation

public actor WebPictures {
    public static let shared = WebPictures(folder: cacheFolder, fetch: download)
    static let byteLimit = 8 << 20
    static let folderLimit = 64 << 20

    private static let cacheFolder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "openspot").appendingPathComponent("pictures")
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    private let folder: URL
    private let limit: Int
    private let fetch: @Sendable (URL) async throws -> Data
    private var loads: [String: Task<String?, Never>] = [:]

    init(folder: URL, limit: Int = folderLimit, fetch: @escaping @Sendable (URL) async throws -> Data) {
        self.folder = folder
        self.limit = limit
        self.fetch = fetch
    }

    public nonisolated static func isWeb(_ text: String) -> Bool {
        text.hasPrefix("https://") && URL(string: text)?.host != nil
    }

    public func path(of text: String) async -> String? {
        guard Self.isWeb(text), let url = URL(string: text) else { return text }
        let file = folder.appendingPathComponent(Self.name(of: url))
        if FileManager.default.fileExists(atPath: file.path) { return file.path }
        if let load = loads[text] { return await load.value }
        let load = Task { await keep(url, at: file) }
        loads[text] = load
        let path = await load.value
        loads[text] = nil
        return path
    }

    private func keep(_ url: URL, at file: URL) async -> String? {
        guard let data = try? await fetch(url), !data.isEmpty, data.count <= Self.byteLimit else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            prune(keeping: file)
            return file.path
        } catch {
            return nil
        }
    }

    private func prune(keeping kept: URL) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let files = ((try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: Array(keys))) ?? [])
            .compactMap { file in (try? file.resourceValues(forKeys: keys)).map { (file, $0.fileSize ?? 0, $0.contentModificationDate ?? .distantPast) } }
            .sorted { $0.2 < $1.2 }
        var total = files.reduce(0) { $0 + $1.1 }
        for (file, size, _) in files where total > limit && file.standardizedFileURL != kept.standardizedFileURL {
            try? FileManager.default.removeItem(at: file)
            total -= size
        }
    }

    private static func name(of url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return url.pathExtension.isEmpty ? hash : "\(hash).\(url.pathExtension)"
    }

    private static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let answer = response as? HTTPURLResponse, answer.statusCode == 200, answer.mimeType?.hasPrefix("image/") == true else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
