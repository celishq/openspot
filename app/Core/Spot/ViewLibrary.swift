import CryptoKit
import Foundation

/// The compiled form of a spot's view: a library with one entry that makes the view (protocol: Views). A library is kept in a cache
/// by the text it was built from, so an unchanged view is built once.
public struct ViewLibrary: Sendable {
    /// The C name of the entry, which returns a retained function from the values, the card and a send to a view.
    public static let entry = "openspot_view_v1"
    static let libraryExtension = "view"
    private static let platform = "apple-macos26.0"
    private static let preludeName = "openspot-view.swift"

    /// The code that Openspot builds with each view: `SpotInput` and the entry. The compiler imports SwiftUI into it. The
    /// card reaches the view as a dictionary, so a new value of the card needs no new entry.
    static let prelude = """
        public struct SpotFonts {
            public let title: Font
            public let detail: Font
            public let metric: Font
            public let value: Font
        }

        public struct SpotInput {
            public let size: CGSize
            public let inset: CGFloat
            public let corner: CGFloat
            public let ink: Color
            public let secondary: Double
            public let accent: Color
            public let font: SpotFonts
            let values: [String: [String]]
            let sender: (String) -> Void
            let cardMaker: @MainActor (String) -> AnyView
            let cardSizer: @MainActor (String) -> CGSize

            init(values: [String: [String]], card: [String: Any], sender: @escaping (String) -> Void) {
                self.values = values
                self.sender = sender
                cardMaker = card["card"] as? @MainActor (String) -> AnyView ?? { _ in AnyView(EmptyView()) }
                cardSizer = card["cardSize"] as? @MainActor (String) -> CGSize ?? { _ in .zero }
                size = card["size"] as? CGSize ?? .zero
                inset = card["inset"] as? CGFloat ?? 13
                corner = card["corner"] as? CGFloat ?? 20
                ink = card["ink"] as? Color ?? .primary
                secondary = card["secondary"] as? Double ?? 0.7
                accent = card["accent"] as? Color ?? .accentColor
                font = SpotFonts(
                    title: card["title"] as? Font ?? .system(size: 13, weight: .medium),
                    detail: card["detail"] as? Font ?? .system(size: 11),
                    metric: card["metric"] as? Font ?? .system(size: 30, weight: .semibold, design: .rounded),
                    value: card["value"] as? Font ?? .system(size: 15, weight: .semibold, design: .rounded)
                )
            }

            public subscript(key: String) -> String? { values[key]?.last }

            public func all(_ key: String) -> [String] { values[key] ?? [] }

            public func send(_ value: String) { sender(value) }

            @MainActor public func card(_ id: String) -> AnyView { cardMaker(id) }

            @MainActor public func cardSize(_ id: String) -> CGSize { cardSizer(id) }
        }

        @_cdecl("\(entry)")
        public func openspotViewEntry() -> UnsafeMutableRawPointer {
            let make: ([String: [String]], [String: Any], @escaping (String) -> Void) -> AnyView = { values, card, send in
                AnyView(SpotView(spot: SpotInput(values: values, card: card, sender: send)))
            }
            return Unmanaged.passRetained(make as AnyObject).toOpaque()
        }

        """

    private let cache: URL
    private let tools: URL

    /// `cache` is the folder of built libraries, and `tools` the folder that holds `xcode-select`, `swiftc` and `lipo`.
    public init(cache: URL, tools: URL = URL(fileURLWithPath: "/usr/bin", isDirectory: true)) {
        self.cache = cache
        self.tools = tools
    }

    /// The libraries in the cache folder of the app.
    public static func standard(cache: URL = AppCache.folder()) -> ViewLibrary {
        ViewLibrary(cache: cache.appendingPathComponent("views", isDirectory: true))
    }

    /// The path of the library that travels beside a view's source, relative when the source path is.
    static func path(beside source: String) -> String {
        (source as NSString).deletingPathExtension + "." + libraryExtension
    }

    /// Whether a file of this path is the library of a view.
    static func isLibrary(_ path: String) -> Bool {
        (path as NSString).pathExtension == libraryExtension
    }

    /// The library of a view: the one that travels beside its source, else one built for this Mac. Throws a fault that
    /// names what is wrong.
    public func library(of source: URL) async throws -> URL {
        let carried = URL(fileURLWithPath: Self.path(beside: source.path))
        if FileManager.default.fileExists(atPath: carried.path) { return carried }
        guard let text = try? Data(contentsOf: source) else {
            throw SpotError.fault("Openspot cannot find the view \(source.lastPathComponent).")
        }
        let name = Self.name(of: text)
        let built = cache.appendingPathComponent("\(name).dylib")
        if FileManager.default.fileExists(atPath: built.path) { return built }
        let data = try await build(source: text, named: source.lastPathComponent, kinds: [Self.thisMac])
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let part = cache.appendingPathComponent("\(name).\(UUID().uuidString).part")
        try data.write(to: part)
        _ = try FileManager.default.replaceItemAt(built, withItemAt: part)
        return built
    }

    /// Builds the library of each view that a script under the folder names, for each kind of Mac, and writes it beside
    /// its source, where `library(of:)` finds it first. Returns the libraries it wrote.
    public func buildViews(under folder: URL) async throws -> [URL] {
        var built: [URL] = []
        let scripts = (FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { FileManager.default.isExecutableFile(atPath: $0.path) && !$0.hasDirectoryPath }
            .sorted { $0.path < $1.path }
        for script in scripts {
            guard let text = try? String(contentsOf: script, encoding: .utf8), let name = SpotHeader(text: text).block.value("view"), !name.hasPrefix("/") else { continue }
            let source = script.deletingLastPathComponent().appendingPathComponent(name)
            guard let data = try? Data(contentsOf: source) else { continue }
            let library = URL(fileURLWithPath: Self.path(beside: source.path))
            try await build(source: data, named: name, kinds: SwiftProgram.kinds).write(to: library)
            built.append(library)
        }
        return built
    }

    /// Compiles a view for these kinds of Mac, such as `arm64` and `x86_64`, and returns the library. `name` is the name of
    /// its file, which an error line shows.
    public func build(source: Data, named name: String, kinds: [String]) async throws -> Data {
        guard (try? await run("xcode-select", ["-p"])) != nil else {
            throw SpotError.fault("To draw a view, install the Command Line Tools: xcode-select --install")
        }
        let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-view-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: place) }
        let prelude = place.appendingPathComponent(Self.preludeName)
        try Data(Self.prelude.utf8).write(to: prelude)
        let file = place.appendingPathComponent(name)
        try source.write(to: file)
        let module = "View\(Self.name(of: source).prefix(16))"
        var parts: [String] = []
        for kind in kinds {
            let part = place.appendingPathComponent(kind).path
            parts.append(part)
            let arguments = ["-emit-library", "-parse-as-library", "-O", "-module-name", module, "-Xfrontend", "-import-module", "-Xfrontend", "SwiftUI", "-target", "\(kind)-\(Self.platform)", prelude.path, file.path, "-o", part]
            do {
                try await run("swiftc", arguments)
            } catch let error as SpotError {
                throw SpotError.fault("This view does not compile. \(error.reason)")
            }
        }
        guard parts.count > 1 else { return try Data(contentsOf: URL(fileURLWithPath: parts[0])) }
        let library = place.appendingPathComponent("library")
        try await run("lipo", ["-create"] + parts + ["-output", library.path])
        return try Data(contentsOf: library)
    }

    private static var thisMac: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }

    /// The name of a library: a hash of its source and of the prelude.
    private static func name(of source: Data) -> String {
        SHA256.hash(data: Data(prelude.utf8) + source).map { String(format: "%02x", $0) }.joined()
    }

    /// Runs a tool and waits for its end. A failure throws the first error line on stderr, with no folders in its path.
    private func run(_ name: String, _ arguments: [String]) async throws {
        let process = Process()
        process.executableURL = tools.appendingPathComponent(name)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let ended = DispatchSemaphore(value: 0)
            process.terminationHandler = { _ in ended.signal() }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }
            DispatchQueue.global().async {
                let text = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                ended.wait()
                guard process.terminationStatus != 0 else { return continuation.resume() }
                let lines = text.split(separator: "\n").map(String.init)
                let line = lines.first { $0.contains("error:") } ?? lines.last ?? "\(name) failed."
                continuation.resume(throwing: SpotError.fault(Self.withoutFolders(line)))
            }
        }
    }

    /// A compiler line with the folders cut from the path at its start.
    private static func withoutFolders(_ line: String) -> String {
        guard line.hasPrefix("/"), let colon = line.firstIndex(of: ":") else { return line }
        let path = line[..<colon]
        return String(line[(path.lastIndex(of: "/").map { line.index(after: $0) } ?? path.startIndex)...])
    }
}
