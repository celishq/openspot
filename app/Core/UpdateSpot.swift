import Foundation

/// The Updates spot, which ships with the app. It shows the version or a downloaded update. A press checks now or restarts
/// into the update, and it warns once before a restart that would stop running calls.
public actor UpdateSpot {
    private let version: String
    private let runningWork: @Sendable () async -> Int
    private let check: @Sendable () async -> Void
    private let restart: @Sendable () async -> Void
    private var ready: String?
    private var warned: Int?

    public init(
        version: String,
        runningWork: @escaping @Sendable () async -> Int,
        check: @escaping @Sendable () async -> Void,
        restart: @escaping @Sendable () async -> Void
    ) {
        self.version = version
        self.runningWork = runningWork
        self.check = check
        self.restart = restart
    }

    /// Takes the version of an update that is downloaded and waits to install.
    public func take(ready version: String) {
        ready = version
    }

    /// Answers one call with the text a script would print.
    public func answer(_ arguments: [String]) async throws -> String {
        switch arguments.first {
        case "read": await state()
        case "run": await press()
        default: throw PluginError.failed(1, "Updates cannot do that.")
        }
    }

    private func state() async -> String {
        guard let ready else { return "title=Updates\ndetail=\(version)\n" }
        let work = await runningWork()
        let detail = work > 0 && warned == work ? "Stops \(Self.calls(work))" : "Update \(ready)"
        return "title=Restart\ndetail=\(detail)\n"
    }

    private func press() async -> String {
        guard ready != nil else {
            await check()
            return ""
        }
        let work = await runningWork()
        guard work > 0, warned != work else {
            await restart()
            return ""
        }
        warned = work
        return "toast=Restarting stops \(Self.calls(work)). Press again to restart.\n"
    }

    private static func calls(_ count: Int) -> String {
        count == 1 ? "1 call" : "\(count) calls"
    }
}

extension UpdateSpot: Equatable {
    public static func == (left: UpdateSpot, right: UpdateSpot) -> Bool {
        left === right
    }
}
