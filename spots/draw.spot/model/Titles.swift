import Foundation

/// The titles of the boards that a list has read. Each one is kept until its file changes, so a list reads a board once
/// and then only asks the disk whether the file is the same.
final class Titles: @unchecked Sendable {
    static let shared = Titles()
    private static let limit = 4096

    private let lock = NSLock()
    private var kept: [String: (stamp: [Int], title: String)] = [:]

    /// The title of a board, or Untitled board for a file that holds none.
    func title(of file: URL) -> String {
        let stamp = Self.stamp(of: file.path)
        if let known = lock.withLock({ kept[file.path] }), known.stamp == stamp, !stamp.isEmpty { return known.title }
        let title = (try? Board.title(at: file)) ?? Board.untitled
        lock.withLock {
            if kept.count >= Self.limit { kept.removeAll() }
            kept[file.path] = (stamp, title)
        }
        return title
    }

    /// What tells one state of a file from the next: its size, its number on the disk and when it changed.
    private static func stamp(of path: String) -> [Int] {
        var info = stat()
        guard stat(path, &info) == 0 else { return [] }
        return [Int(info.st_size), Int(info.st_ino), info.st_mtimespec.tv_sec, info.st_mtimespec.tv_nsec]
    }
}
