import Foundation

struct SandboxCalls {
    let folder: URL
    let app: (any RunningApp)?

    func open(_ path: String?, isCareful: Bool) -> CommandAPI.Work? {
        guard let app else { return nil }
        let file = path.map { URL(fileURLWithPath: $0, relativeTo: folder).absoluteURL }
        return {
            await app.sandbox(file, isCareful: isCareful)
            return CommandAnswer()
        }
    }
}
