import Foundation

/// A hold on a board's file while a window shows it, so a second open of that board brings the first window forward.
struct Lock {
    private let handle: Int32

    /// Takes the lock of a board, or returns nil when another window holds it. A lock file that cannot open holds nothing.
    static func claim(_ file: URL) -> Lock? {
        let handle = open(file.path + ".lock", O_CREAT | O_RDWR, 0o644)
        guard handle >= 0 else { return Lock(handle: -1) }
        guard flock(handle, LOCK_EX | LOCK_NB) == 0 else {
            close(handle)
            return nil
        }
        return Lock(handle: handle)
    }

    func release() {
        if handle >= 0 { close(handle) }
    }
}
