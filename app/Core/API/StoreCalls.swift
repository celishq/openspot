import Foundation

/// The calls of `openspot store`: the spots that the store holds, and the publish of a spot of the spots folder to it.
struct StoreCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    func list(frame: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let config = ConfigFile.standard(environment: environment).read()
            let store = SpotsFolder.config(environment: environment, home: FileManager.default.homeDirectoryForCurrentUser).appendingPathComponent("store", isDirectory: true)
            let list = StoreList(folder: SpotsFolder.standard(environment: environment), config: config, store: store)
            return frame ? list.frame() : try list.json()
        }
    }

    /// Publishes a spot in the running app, which signs it with the account key and shows how it went.
    func publish(_ id: String) -> CommandAPI.Work {
        guard let app else { return CommandAnswer.notRunning("store publish \(id)") }
        return CommandAnswer.work {
            switch await app.publish(id) {
            case .published: return "Published \(id).\n"
            case .unchanged: return "\(id) has no change since its last publish.\n"
            case .needsReadme: throw SpotError.failed(1, "\(id) has no readme.md. Write one beside its script, then publish again.")
            case .notOwn: throw SpotError.failed(1, "`\(id)` is not a spot of your spots folder, so it cannot be published.")
            case .failed: throw SpotError.failed(1, "\(id) was not published. The toast in Openspot says why.")
            }
        }
    }
}
