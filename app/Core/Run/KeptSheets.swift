import Foundation

@MainActor
public final class KeptSheets {
    static let writePause = Duration.seconds(2)
    static let byteLimit = 256 << 10

    let folder: URL?
    private var texts: [String: String] = [:]
    private var frames: [String: Frame] = [:]
    private var unwritten: [String: String] = [:]
    private var writing: Task<Void, Never>?
    public private(set) var isRead = false

    public init(folder: URL?) {
        self.folder = folder
    }

    private nonisolated static func name(of id: String) -> String {
        id.replacingOccurrences(of: "/", with: "_")
    }

    public nonisolated static func read(_ folder: URL?) -> [String: String] {
        guard let folder, let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { return [:] }
        var read: [String: String] = [:]
        for file in files where file.pathExtension == "frame" {
            if let text = try? String(contentsOf: file, encoding: .utf8) { read[file.deletingPathExtension().lastPathComponent] = text }
        }
        return read
    }

    public func take(_ read: [String: String]) {
        isRead = true
        for (name, text) in read where texts[name] == nil {
            texts[name] = text
            frames[name] = Frame(text: text)
        }
    }

    func frame(of id: String) -> Frame? {
        frames[Self.name(of: id)]
    }

    func keep(_ text: String, frame: Frame, of id: String) {
        let name = Self.name(of: id)
        guard texts[name] != text, text.utf8.count <= Self.byteLimit else { return }
        texts[name] = text
        frames[name] = frame
        unwritten[name] = text
        guard folder != nil, writing == nil else { return }
        writing = Task { [weak self] in
            try? await Task.sleep(for: Self.writePause, tolerance: Self.writePause)
            guard let self else { return }
            let texts = unwritten
            unwritten = [:]
            await Self.write(texts, to: folder)
            writing = nil
        }
    }

    @concurrent
    private nonisolated static func write(_ texts: [String: String], to folder: URL?) async {
        guard let folder else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (name, text) in texts {
            try? text.write(to: folder.appendingPathComponent(name + ".frame"), atomically: true, encoding: .utf8)
        }
    }
}
