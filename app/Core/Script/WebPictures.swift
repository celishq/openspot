import CryptoKit
import Foundation

/// The pictures that an `icon` names by an https URL. Each one is fetched once, the first time a view draws it, into a cache
/// folder, and kept there. A failed or too large fetch keeps nothing, so the next draw tries again.
public actor WebPictures {
    /// The pictures of the app, in its cache folder.
    public static let shared = WebPictures(folder: cacheFolder, fetch: download)
    /// The most bytes that one picture can hold.
    static let limit = 8 << 20

    private static let cacheFolder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent(Bundle.main.bundleIdentifier ?? "openspot").appendingPathComponent("pictures")
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        return URLSession(configuration: configuration)
    }()

    private let folder: URL
    private let fetch: @Sendable (URL) async throws -> Data
    private var loads: [String: Task<String?, Never>] = [:]

    init(folder: URL, fetch: @escaping @Sendable (URL) async throws -> Data) {
        self.folder = folder
        self.fetch = fetch
    }

    /// Whether a value names a picture on the web.
    public nonisolated static func isWeb(_ text: String) -> Bool {
        text.hasPrefix("https://") && URL(string: text)?.host != nil
    }

    /// The path of the file that holds the picture a value names: the value itself when it is a path, or the kept copy of a
    /// picture on the web, which it fetches the first time. Nil when that fetch fails.
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
        guard let data = try? await fetch(url), !data.isEmpty, data.count <= Self.limit else { return nil }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: file, options: .atomic)
            return file.path
        } catch {
            return nil
        }
    }

    /// A file name of the URL's hash, with the extension of its path.
    private static func name(of url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        return url.pathExtension.isEmpty ? hash : "\(hash).\(url.pathExtension)"
    }

    /// Fetches a picture with no cookies and no shared cache, and fails on an answer that is not a picture.
    private static func download(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let answer = response as? HTTPURLResponse, answer.statusCode == 200, answer.mimeType?.hasPrefix("image/") == true else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
