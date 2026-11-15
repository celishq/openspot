import Foundation

struct SandboxCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

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
