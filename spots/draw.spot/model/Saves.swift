import Foundation

/// The writes of boards to the disk: one at a time, in the order they were asked, off the main thread. Each file is
/// written whole beside the old one and then takes its place, so a reader never gets half a board.
final class Saves: @unchecked Sendable {
    static let shared = Saves()

    private let queue = DispatchQueue(label: "draw.saves", qos: .userInitiated)
    /// The boards whose last write failed. Only the queue reads and changes it.
    private var unwritten: Set<String> = []

    /// Writes a board. `failed` runs when the board could not be written.
    func write(_ board: Board, to file: URL, failed: @escaping @Sendable () -> Void) {
        queue.async { [self] in
            do {
                try board.save(to: file)
                unwritten.remove(file.path)
            } catch {
                unwritten.insert(file.path)
                failed()
            }
        }
    }

    /// Writes the picture of a board beside its file, unless the last write of the board failed.
    func write(picture: Data, of file: URL) {
        queue.async { [self] in
            guard !unwritten.contains(file.path) else { return }
            try? picture.write(to: file.deletingPathExtension().appendingPathExtension("png"), options: .atomic)
        }
    }

    /// Returns when each write asked so far is on the disk.
    func wait() {
        queue.sync {}
    }

    /// Holds the writes back until `resume`.
    func pause() {
        queue.suspend()
    }

    func resume() {
        queue.resume()
    }
}
