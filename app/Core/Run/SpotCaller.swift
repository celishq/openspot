import Foundation

public final class SpotCaller: @unchecked Sendable, Equatable {
    public let spot: Spot
    let keepsFix: Bool
    private let lock = NSLock()
    private var reasonValue: String?
    private var fixValue: URL?
    private var channelValue: RunChannel?
    private var groupValue: (id: pid_t, start: UInt64)?
    private var endedValue = false
    private var callValue: OpenCall?
    private weak var processValue: ScriptProcess?

    init(spot: Spot, reason: String? = nil, keepsFix: Bool = false) {
        self.spot = spot
        self.keepsFix = keepsFix
        reasonValue = reason
    }

    public static func == (left: SpotCaller, right: SpotCaller) -> Bool {
        left === right
    }

    var reason: String? {
        get { lock.withLock { reasonValue } }
        set { lock.withLock { reasonValue = newValue } }
    }

    var call: OpenCall? {
        get { lock.withLock { callValue } }
        set { lock.withLock { callValue = newValue } }
    }

    var group: (id: pid_t, start: UInt64)? {
        get { lock.withLock { groupValue } }
        set { lock.withLock { groupValue = newValue } }
    }

    var process: ScriptProcess? {
        get { lock.withLock { processValue } }
        set { lock.withLock { processValue = newValue } }
    }

    func holdLimit() {
        process?.holdLimit()
    }

    func releaseLimit() {
        process?.releaseLimit()
    }

    var hasEnded: Bool {
        lock.withLock { endedValue }
    }

    func channel(serving api: CommandAPI) -> RunChannel? {
        lock.withLock {
            guard !endedValue else { return nil }
            if let channelValue { return channelValue }
            channelValue = RunChannel { [self] in CommandSocket.serve($0, caller: self, api) }
            return channelValue
        }
    }

    func note(_ fix: URL?) {
        lock.withLock {
            guard !endedValue, keepsFix else { return }
            fixValue = fix
        }
    }

    func takeFix() -> URL? {
        lock.withLock {
            defer { fixValue = nil }
            return fixValue
        }
    }

    func end() {
        let channel = lock.withLock {
            endedValue = true
            callValue = nil
            defer { channelValue = nil }
            return channelValue
        }
        channel?.close()
    }
}
