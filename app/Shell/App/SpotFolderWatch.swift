import CoreServices
import Foundation

/// A watch of the plugins folder and the folders in it, which calls back on the main thread a moment after each change
/// settles, such as an agent that writes a spot.
@MainActor
final class SpotFolderWatch {
    private static let settle: CFTimeInterval = 0.3

    private var stream: FSEventStreamRef?
    private let onChange: @MainActor () -> Void

    /// Starts to watch the folder, and makes it when it does not exist yet.
    init(folder: URL, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watch = Unmanaged<SpotFolderWatch>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { watch.onChange() }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(nil, callback, &context, [folder.path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), Self.settle, flags) else { return }
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        self.stream = stream
    }

    nonisolated deinit {}

    /// Stops the watch.
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
