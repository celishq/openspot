import Foundation

/// The hold of one Draw on the folder of the boards, so that one process at a time writes them. The Mac lets it go
/// when the process ends, however it ends.
struct Lock {
    private let handle: Int32

    /// Takes the hold on a folder of boards, or returns nil while another Draw has it. A folder where the lock file
    /// cannot open holds nothing, so the write that follows says what is wrong with it.
    static func claim(_ folder: URL) -> Lock? {
        let handle = open(folder.appendingPathComponent(".draw.lock").path, O_CREAT | O_RDWR | O_CLOEXEC, 0o644)
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
