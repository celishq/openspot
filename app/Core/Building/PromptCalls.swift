import Foundation

struct PromptCalls {
    let mac: Mac
    let places: AppPlaces
    let runs: SpotRuns?

    func new(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work { [places] in
            guard !words.isEmpty else { throw SpotError.failed(1, AgentPrompt.wordsNeeded) }
            return Self.prompt(in: places).building(words)
        }
    }

    func change(_ id: String, words: String, failure: String?) -> CommandAPI.Work {
        CommandAnswer.work { [places, runs] in
            let folder = places.spots
            guard !folder.isCore(id: id) else { throw SpotError.failed(1, SpotsFolder.uneditable(id)) }
            guard let spot = try folder.scan().scripts.first(where: { $0.id == id }), !spot.isBuiltIn else {
                throw SpotError.failed(1, "Openspot cannot find \(id). Check its ID with `openspot spot list`.")
            }
            let prompt = Self.prompt(in: places)
            let evidence = await SpotEvidence.read(of: id, runs: runs, stats: places.stats, app: prompt.app)
            return prompt.changing(spot.url, wish: words.isEmpty ? nil : words, failure: failure, evidence: evidence)
        }
    }

    func theme(_ name: String, words: String) -> CommandAPI.Work {
        CommandAnswer.work { [mac, places] in
            let themes = ThemeFolder(config: places.config, builtIn: mac.theme)
            let found = try themes.find(name)
            let app = AgentPrompt.command(of: Bundle.main.executablePath ?? "openspot")
            return ThemePrompt(theme: found.name, folder: themes.url, isBuiltIn: found.isBuiltIn, base: mac.theme, app: app).asking(words)
        }
    }

    private static func prompt(in places: AppPlaces) -> AgentPrompt {
        AgentPrompt(places: places)
    }
}
