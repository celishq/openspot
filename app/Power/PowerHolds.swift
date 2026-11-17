import Foundation

final class PowerHolds: NSObject, NSXPCListenerDelegate, @unchecked Sendable {
    private static let mark = URL(fileURLWithPath: "/private/var/db/openspot.lid-closed")
    private static let idle: TimeInterval = 10
    private let lock = NSLock()
    private var holds: [ObjectIdentifier: Int] = [:]
    private var links = 0

    func start() {
        if FileManager.default.fileExists(atPath: Self.mark.path), Self.pmset(sleep: true) {
            try? FileManager.default.removeItem(at: Self.mark)
        }
        endWhenIdle()
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        let link = PowerLink(holds: self)
        let id = ObjectIdentifier(link)
        connection.exportedInterface = NSXPCInterface(with: PowerService.self)
        connection.exportedObject = link
        connection.invalidationHandler = { [weak self] in self?.drop(id) }
        lock.withLock { links += 1 }
        connection.resume()
        return true
    }

    func hold(_ id: ObjectIdentifier) -> String? {
        lock.withLock {
            if holds.values.reduce(0, +) == 0 {
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

    func release(_ id: ObjectIdentifier, all: Bool = false) {
        lock.withLock {
            guard let count = holds[id] else { return }
            holds[id] = all || count <= 1 ? nil : count - 1
            if holds.isEmpty, Self.pmset(sleep: true) {
                try? FileManager.default.removeItem(at: Self.mark)
            }
        }
    }

    private func drop(_ id: ObjectIdentifier) {
        release(id, all: true)
        lock.withLock { links -= 1 }
        endWhenIdle()
    }

    private func endWhenIdle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idle) { [weak self] in
            guard let self, self.lock.withLock({ self.links == 0 && self.holds.isEmpty }) else { return }
            exit(0)
        }
    }

    private static func pmset(sleep: Bool) -> Bool {
        PowerTool.run("/usr/bin/pmset", ["disablesleep", sleep ? "0" : "1"]).map { _ in true } ?? false
    }
}
