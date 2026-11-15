import Foundation

/// The writes of boards to the disk: one at a time, in the order they were asked, off the main thread. Each file is
/// written whole beside the old one and then takes its place, so a reader never gets half a board.
final class Saves: @unchecked Sendable {
    static let shared = Saves()

    private let queue = DispatchQueue(label: "draw.saves", qos: .userInitiated)

    /// Writes a board, and its picture when there is one. `failed` runs when the board could not be written.
    func write(_ board: Board, picture: Data?, to file: URL, failed: @escaping @Sendable () -> Void) {
        queue.async {
            do {
                try board.save(to: file)
            } catch {
                return failed()
            }
            try? picture?.write(to: file.deletingPathExtension().appendingPathExtension("png"), options: .atomic)
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
