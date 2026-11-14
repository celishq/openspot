import Foundation

/// The calls of `openspot store`: the spots that the store holds, the get of one, and the publish of a spot of the spots
/// folder to it.
struct StoreCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    /// The store as the config and the spots folder of this environment see it.
    private var store: SpotStore {
        SpotStore(url: SpotStore.url(environment: environment), folder: SpotsFolder.standard(environment: environment), arrangement: ConfigFile.standard(environment: environment).read().arrangement)
    }

    func list(frame: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [store] in frame ? store.frame() : try store.json() }
    }

    /// Gets a spot of the store, and tells the running app of the change.
    func get(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [store, environment, app] in
            let item = try await store.get(id, config: ConfigFile.standard(environment: environment), environment: environment)
            await app?.configChanged(.spots([id]))
            return "Added \(item.spot.name).\n"
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
