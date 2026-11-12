import Foundation

/// The stop of a command that runs scripts in the terminal, such as `openspot spot run` or `openspot check` (S13). It knows
/// the process group of each script that this program runs, and on Ctrl-C or the terminate signal each group gets the
/// terminate signal, then the kill signal, and the program exits with 130.
public enum TerminalStop {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var groups: Set<pid_t> = []
    nonisolated(unsafe) private static var sources: [any DispatchSourceSignal] = []
    private static let checkPause: TimeInterval = 0.02

    /// Stops each group and exits with 130 at Ctrl-C or the terminate signal, from now on. It acts on the main queue, so
    /// that no work there exits first with the code of a stopped script.
    public static func watch(pause: TimeInterval = 2) {
        lock.withLock {
            guard sources.isEmpty else { return }
            for number in [SIGINT, SIGTERM] {
                signal(number, SIG_IGN)
                let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
                source.setEventHandler {
                    stopEach(pause: pause)
                    exit(130)
                }
                source.resume()
                sources.append(source)
            }
        }
    }

    /// Gives each group the terminate signal, waits up to `pause` seconds for them to end, and kills what still runs.
    static func stopEach(pause: TimeInterval) {
        let live = lock.withLock { groups }
        live.forEach { kill(-$0, SIGTERM) }
        let deadline = Date().addingTimeInterval(pause)
        while live.contains(where: { kill(-$0, 0) == 0 }), Date() < deadline { Thread.sleep(forTimeInterval: checkPause) }
        live.forEach { kill(-$0, SIGKILL) }
    }

    /// Keeps a new group, and lets go of each one that has ended.
    static func enter(_ group: pid_t) {
        lock.withLock {
            groups = groups.filter { kill(-$0, 0) == 0 }
            groups.insert(group)
        }
    }

    static func leave(_ group: pid_t) {
        lock.withLock { _ = groups.remove(group) }
    }
}
