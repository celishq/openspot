import Foundation

final class PowerHolds: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private static let mark = URL(fileURLWithPath: "/private/var/db/openspot.lid-closed")
    private static let idle: TimeInterval = 10
    private let lock = NSLock()
    private var holds: Set<UUID> = []
    private var links = 0
    private var isEnding = false

    func start() {
        lock.withLock { letGo() }
        endWhenIdle()
    }

    func stop() -> Never {
        lock.lock()
        isEnding = true
        letGo()
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
            holds.insert(id)
            return nil
        }
    }

    private func drop(_ id: UUID) {
        lock.withLock {
            links -= 1
            guard holds.remove(id) != nil, holds.isEmpty else { return }
            letGo()
        }
        endWhenIdle()
    }

    private func letGo() {
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
