import Foundation

struct PlaygroundCalls {
    let folder: URL
    let app: (any RunningApp)?

    func open(_ path: String?, isCareful: Bool) -> CommandAPI.Work? {
        guard let app else { return nil }
        let file = path.map { URL(fileURLWithPath: $0, relativeTo: folder).absoluteURL }
        return {
            await app.playground(file, isCareful: isCareful)
            return CommandAnswer()
        }
    }
}
