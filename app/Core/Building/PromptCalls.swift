import Foundation

struct PromptCalls {
    let mac: Mac
    let places: AppPlaces
    let runs: SpotRuns?

    func new(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work { [places] in
            guard !words.isEmpty else { throw SpotError.failed(1, AgentPrompt.wordsNeeded) }
            return AgentPrompt(places: places).building(words)
        }
    }

    func change(_ id: String, words: String, failure: String?) -> CommandAPI.Work {
        CommandAnswer.work { [places, runs] in
            let folder = places.spots
            guard !folder.isCore(id: id) else { throw SpotError.failed(1, SpotsFolder.uneditable(id)) }
            guard let spot = try folder.scan().scripts.first(where: { $0.id == id }), !spot.isBuiltIn else {
                throw SpotError.failed(1, "Openspot cannot find \(id). Check its ID with `openspot spot list`.")
            }
            return await AgentPrompt(places: places).readChange(of: spot.url, id: id, wish: words.isEmpty ? nil : words, failure: failure, runs: runs, stats: places.stats)
        }
    }

    func theme(_ name: String, words: String) -> CommandAPI.Work {
        CommandAnswer.work { [mac, places] in
            guard !words.isEmpty else { throw SpotError.failed(1, ThemePrompt.wordsNeeded) }
            let themes = ThemeFolder(config: places.config, builtIn: mac.theme)
            let found = try themes.find(name)
            return ThemePrompt(theme: found.name, folder: themes.url, isBuiltIn: found.isBuiltIn, base: mac.theme, app: AgentPrompt.command()).asking(words)
        }
    }
}
