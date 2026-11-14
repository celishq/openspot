import Foundation

public struct PictureFile: Sendable {
    public let path: String

    nonisolated(unsafe) static var reads = 0

    public init(path: String) {
        self.path = path
    }

    public var changed: Double? {
        Self.reads += 1
        var info = stat()
        guard stat(path, &info) == 0 else { return nil }
        return Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1e9
    }

    public var changes: AsyncStream<Double?> {
        AsyncStream { continuation in
            let watch = PictureWatch(file: self, continuation: continuation)
            continuation.onTermination = { _ in watch.stop() }
            watch.start()
        }
    }
}

private final class PictureWatch: @unchecked Sendable {
    private let file: PictureFile
    private let continuation: AsyncStream<Double?>.Continuation
    private let queue = DispatchQueue(label: "openspot.picture-watch", qos: .utility)
    private var folderSource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var last: Double?

    init(file: PictureFile, continuation: AsyncStream<Double?>.Continuation) {
        self.file = file
        self.continuation = continuation
    }

    func start() {
        queue.async { [self] in
            last = file.changed
            folderSource = source(at: (file.path as NSString).deletingLastPathComponent, events: [.write, .rename, .delete])
            watchFile()
        }
    }

    func stop() {
        queue.async { [self] in
            folderSource?.cancel()
            fileSource?.cancel()
            folderSource = nil
            fileSource = nil
        }
    }

    private func watchFile() {
        fileSource?.cancel()
        fileSource = source(at: file.path, events: [.write, .extend, .attrib, .delete, .rename])
    }

    private func source(at path: String, events: DispatchSource.FileSystemEvent) -> DispatchSourceFileSystemObject? {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return nil }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: events, queue: queue)
        source.setEventHandler { [weak self] in self?.check() }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        return source
    }

    private func check() {
        guard folderSource != nil else { return }
        let now = file.changed
        guard now != last else { return }
        last = now
        watchFile()
        continuation.yield(now)
    }
}
