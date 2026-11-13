import CoreServices
import Foundation
import OpenspotCore

/// A watch of the spots folder and the folders in it, and of the config file, which calls back on the main thread a moment
/// after a change that a scan or a reload reads settles, such as an agent that writes a spot or a person who edits the config.
@MainActor
final class SpotsFolderWatch {
    private static let settle: CFTimeInterval = 0.3

    private var stream: FSEventStreamRef?
    private let onChange: @MainActor () -> Void
    private let folder: SpotsFolder
    private let config: String

    /// Starts to watch the folder and the config file, and makes the folder when it does not exist yet.
    init(folder: URL, config: URL, onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
        self.folder = SpotsFolder(url: folder)
        self.config = config.resolvingSymlinksInPath().path
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
            guard let info else { return }
            let watch = Unmanaged<SpotsFolderWatch>.fromOpaque(info).takeUnretainedValue()
            let changed = (Unmanaged<CFArray>.fromOpaque(paths).takeUnretainedValue() as? [String]) ?? []
            MainActor.assumeIsolated {
                if changed.contains(where: { watch.folder.reads($0) || $0 == watch.config }) { watch.onChange() }
            }
        }
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(nil, callback, &context, [folder.path, config.deletingLastPathComponent().path] as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), Self.settle, flags) else { return }
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
