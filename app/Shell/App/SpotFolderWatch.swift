import CoreServices
import Foundation
import OpenspotCore

/// A watch of the spots folder and the folders in it, which calls back on the main thread a moment after a change that a
/// scan reads settles, such as an agent that writes a spot.
@MainActor
final class SpotFolderWatch {
    private static let settle: CFTimeInterval = 0.3

    private var stream: FSEventStreamRef?
    private let onChange: @MainActor () -> Void
    private let folder: SpotFolder

    /// Starts to watch the folder, and makes it when it does not exist yet.
    init(folder: URL, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        self.folder = SpotFolder(url: folder)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
            guard let info else { return }
            let watch = Unmanaged<SpotFolderWatch>.fromOpaque(info).takeUnretainedValue()
            let changed = (Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String]) ?? []
            MainActor.assumeIsolated {
                if changed.contains(where: watch.folder.reads) { watch.onChange() }
            }
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
