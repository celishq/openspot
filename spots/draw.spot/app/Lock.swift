import Foundation

/// A hold on the folder of the boards while Draw runs, so a second start of Draw hands its board to the first one.
struct Lock {
    private let handle: Int32

    /// Takes the lock beside this file, or returns nil when a running Draw holds it. A lock file that cannot open holds nothing.
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
