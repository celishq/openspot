import Foundation

struct StoreCalls {
    let environment: [String: String]
    let app: (any RunningApp)?

    private static func store(in environment: [String: String]) -> SpotStore {
        SpotStore(url: SpotStore.url(environment: environment), folder: SpotsFolder.standard(environment: environment), arrangement: ConfigFile.standard(environment: environment).read().arrangement)
    }

    func list(frame: Bool) -> CommandAPI.Work {
        CommandAnswer.work { [environment] in
            let store = Self.store(in: environment)
            return frame ? store.frame() : try store.json()
        }
    }

    func get(_ id: String) -> CommandAPI.Work {
        CommandAnswer.work { [environment, app] in
            let item = try await Self.store(in: environment).get(id, config: ConfigFile.standard(environment: environment), environment: environment)
            await app?.configChanged(.spots([id]))
            return "Added \(item.spot.name).\n"
        }
    }

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
