import Foundation

/// The calls of `openspot prompt`: the prompt that asks a coding agent to build a spot, or with no words, to ask the
/// person what the spot should do first, and the prompt that asks it to change a spot.
struct PromptCalls {
    let mac: any Mac
    let environment: [String: String]

    func new(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work { [mac, environment] in
            let prompt = Self.prompt(in: SpotsFolder.standard(environment: environment).url, mac: mac)
            return words.isEmpty ? prompt.interviewing() : prompt.building(words)
        }
    }

    /// The prompt that asks an agent to change a spot: as the words say, or with none, after it asks what to change. A core
    /// spot is copied into the spots folder first, and its copy changes.
    func change(_ id: String, words: String, failure: String?) -> CommandAPI.Work {
        CommandAnswer.work { [mac, environment] in
            let folder = SpotsFolder.standard(environment: environment)
            guard let spot = try folder.scan().scripts.first(where: { $0.id == id }), !spot.isBuiltIn else {
                throw SpotError.failed(1, "Openspot cannot find \(id). Check its ID with `openspot spot list`.")
            }
            let prompt = Self.prompt(in: folder.url, mac: mac)
            let core = spot.url.deletingLastPathComponent()
            let copy = folder.url.appendingPathComponent(core.lastPathComponent, isDirectory: true)
            let file = folder.isCore(spot) ? copy.appendingPathComponent(spot.url.lastPathComponent) : spot.url
            let change = words.isEmpty ? prompt.changing(file, failure: failure) : prompt.changing(file, wish: words)
            return folder.isCore(spot) ? "\(prompt.copying(core, to: copy))\n\(change)" : change
        }
    }

    private static func prompt(in folder: URL, mac: any Mac) -> AgentPrompt {
        AgentPrompt(folder: folder, guide: mac.guide ?? folder, app: AgentPrompt.command(of: Bundle.main.executablePath ?? "openspot"))
    }
}
