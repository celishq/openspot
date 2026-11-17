import Foundation

final class PowerHolds: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private static let mark = URL(fileURLWithPath: "/private/var/db/openspot.lid-closed")
    private static let idle: TimeInterval = 10
    private let lock = NSLock()
    private var holds: [UUID: Int] = [:]
    private var links = 0
    private var isEnding = false

    func start() {
        lock.withLock { letGoAfterAnEnd() }
        endWhenIdle()
    }

    func stop() -> Never {
        lock.lock()
        isEnding = true
        if !holds.isEmpty { letGoAfterAnEnd() }
        exit(0)
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let id = UUID()
        let accepted = lock.withLock {
            guard !isEnding else { return false }
            links += 1
            return true
        }
        guard accepted else { return false }
        connection.exportedInterface = NSXPCInterface(with: PowerService.self)
        connection.exportedObject = PowerLink(holds: self, id: id)
        connection.invalidationHandler = { [weak self] in self?.drop(id) }
        connection.resume()
        return true
    }

    func hold(_ id: UUID) -> String? {
        lock.withLock {
            if holds.isEmpty, !Self.isSleepDisabled() {
                FileManager.default.createFile(atPath: Self.mark.path, contents: nil)
                guard Self.pmset(sleep: false) else {
                    try? FileManager.default.removeItem(at: Self.mark)
                    return "pmset could not keep the Mac awake with the lid closed."
                }
            }
            holds[id, default: 0] += 1
            return nil
        }
    }

    func release(_ id: UUID, all: Bool = false) {
        lock.withLock {
            guard let count = holds[id] else { return }
            holds[id] = all || count <= 1 ? nil : count - 1
            if holds.isEmpty { letGoAfterAnEnd() }
        }
    }

    private func drop(_ id: UUID) {
        release(id, all: true)
        lock.withLock { links -= 1 }
        endWhenIdle()
    }

    private func letGoAfterAnEnd() {
        guard FileManager.default.fileExists(atPath: Self.mark.path), Self.pmset(sleep: true) else { return }
        try? FileManager.default.removeItem(at: Self.mark)
    }

    private func endWhenIdle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idle) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            guard self.links == 0, self.holds.isEmpty else { return self.lock.unlock() }
            self.isEnding = true
            exit(0)
        }
    }

    private static func isSleepDisabled() -> Bool {
        let settings = PowerTool.run("/usr/bin/pmset", ["-g"]).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return settings.split(separator: "\n").contains { line in
            let words = line.split(whereSeparator: \.isWhitespace)
            return words.first == "SleepDisabled" && words.last == "1"
        }
    }

    private static func pmset(sleep: Bool) -> Bool {
        PowerTool.run("/usr/bin/pmset", ["disablesleep", sleep ? "0" : "1"]) != nil
    }
}
