import Foundation

/// The call of `openspot sandbox`, which opens its window in the running app. A relative file starts in the working folder of
/// the caller.
struct SandboxCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    /// Opens the window and returns once the person closes it, or returns nil when no app runs, so that a process of its
    /// own opens it. A script runs in Careful mode when `isCareful` (Z8).
    func open(_ path: String?, isCareful: Bool) -> CommandAPI.Work? {
        guard let app else { return nil }
        let place = URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
        let file = path.map { URL(fileURLWithPath: $0, relativeTo: place).absoluteURL }
        return {
            await app.sandbox(file, isCareful: isCareful)
            return CommandAnswer()
        }
    }
}
