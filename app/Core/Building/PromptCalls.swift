import Foundation

struct PromptCalls {
    let mac: Mac
    let environment: [String: String]
    let runs: SpotRuns?

    func new(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work { [mac, environment] in
            let prompt = Self.prompt(in: SpotsFolder.standard(environment: environment).url, mac: mac)
            return words.isEmpty ? prompt.interviewing() : prompt.building(words)
        }
    }

    func change(_ id: String, words: String, failure: String?) -> CommandAPI.Work {
        CommandAnswer.work { [mac, environment, runs] in
            let folder = SpotsFolder.standard(environment: environment)
            guard let spot = try folder.scan().scripts.first(where: { $0.id == id }), !spot.isBuiltIn else {
                throw SpotError.failed(1, "Openspot cannot find \(id). Check its ID with `openspot spot list`.")
            }
            let prompt = Self.prompt(in: folder.url, mac: mac)
            let core = spot.url.deletingLastPathComponent()
            let copy = folder.url.appendingPathComponent(core.lastPathComponent, isDirectory: true)
            let file = folder.isCore(spot) ? copy.appendingPathComponent(spot.url.lastPathComponent) : spot.url
            let evidence = SpotEvidence(of: id, in: await SpotUsage.days(SpotEvidence.days, runs: runs, environment: environment), app: prompt.app)
            let change = words.isEmpty ? prompt.changing(file, failure: failure, evidence: evidence) : prompt.changing(file, wish: words, evidence: evidence)
            return folder.isCore(spot) ? "\(prompt.copying(core, to: copy))\n\(change)" : change
        }
    }

    private static func prompt(in folder: URL, mac: Mac) -> AgentPrompt {
        AgentPrompt(folder: folder, guide: mac.guide ?? folder, app: AgentPrompt.command(of: Bundle.main.executablePath ?? "openspot"))
    }
}
