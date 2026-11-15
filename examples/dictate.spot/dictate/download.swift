import Foundation

/// The download of the Whisper model into the spot's data folder by `curl`, with its share from 0 to 1. The bytes go to a
/// `.part` file beside the model, so a download that breaks, or a spot that ends, goes on later from the bytes it has. A
/// server that cannot resume sends the whole file again. The model lands only at its full size, and a stop or a part of
/// another size leaves no part file.
final class Download {
    enum End { case landed, failed, stopped, wrongSize }

    static let source = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin"
    /// The size of the model in bytes, or `DICTATE_SIZE` for a test.
    static let size = Int64(ProcessInfo.processInfo.environment["DICTATE_SIZE"] ?? "") ?? 1_624_555_275
    /// The code of `curl` for a server that cannot send the rest of a file.
    private static let cannotResume: Int32 = 33

    let target: URL
    private let part: URL
    private let progress: (Double) -> Void
    private let end: (End) -> Void
    private var process: Process?
    private var timer: Timer?
    private var isStopped = false

    init(to target: URL, progress: @escaping (Double) -> Void, end: @escaping (End) -> Void) {
        self.target = target
        part = target.appendingPathExtension("part")
        self.progress = progress
        self.end = end
        try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        fetch(again: true)
    }

    /// The share of the model on disk.
    var share: Double {
        let have = (try? FileManager.default.attributesOfItem(atPath: part.path)[.size] as? Int64) ?? 0
        return min(Double(have) / Double(Self.size), 1)
    }

    /// Ends `curl` and removes the bytes it has.
    func stop() {
        isStopped = true
        process?.terminate()
    }

    /// Ends `curl` and keeps the bytes it has, as the end of the spot does.
    func pause() {
        process?.terminate()
    }

    private func fetch(again: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["curl", "-fsL", "-C", "-", "-o", part.path, Self.source]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { ended in
            DispatchQueue.main.async { self.ended(ended.terminationStatus, again: again) }
        }
        do {
            try process.run()
        } catch {
            return DispatchQueue.main.async { self.end(.failed) }
        }
        self.process = process
        var shown = Int(share * 100)
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, Int(share * 100) != shown else { return }
            shown = Int(share * 100)
            progress(share)
        }
    }

    private func ended(_ code: Int32, again: Bool) {
        timer?.invalidate()
        timer = nil
        process = nil
        if isStopped {
            try? FileManager.default.removeItem(at: part)
            return end(.stopped)
        }
        if code == Self.cannotResume, again {
            try? FileManager.default.removeItem(at: part)
            return fetch(again: false)
        }
        guard code == 0 else { return end(.failed) }
        let have = (try? FileManager.default.attributesOfItem(atPath: part.path)[.size] as? Int64) ?? 0
        guard have == Self.size else {
            try? FileManager.default.removeItem(at: part)
            return end(.wrongSize)
        }
        try? FileManager.default.removeItem(at: target)
        try? FileManager.default.moveItem(at: part, to: target)
        end(FileManager.default.fileExists(atPath: target.path) ? .landed : .failed)
    }
}
