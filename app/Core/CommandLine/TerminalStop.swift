import Foundation

public enum TerminalStop {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var groups: Set<pid_t> = []
    nonisolated(unsafe) private static var sources: [any DispatchSourceSignal] = []
    private static let checkPause: TimeInterval = 0.02

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

    static func stopEach(pause: TimeInterval) {
        let live = lock.withLock { groups }
        live.forEach { kill(-$0, SIGTERM) }
        let deadline = Date().addingTimeInterval(pause)
        while live.contains(where: { kill(-$0, 0) == 0 }), Date() < deadline { Thread.sleep(forTimeInterval: checkPause) }
        live.forEach { kill(-$0, SIGKILL) }
    }

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
