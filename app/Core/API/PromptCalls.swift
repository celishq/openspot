import Foundation

/// The call of `openspot prompt new`: the prompt that asks a coding agent to build a spot.
struct PromptCalls {
    let mac: any Mac
    let environment: [String: String]

    func new(_ words: String) -> CommandAPI.Work {
        CommandAnswer.work { [mac, environment] in
            let folder = SpotsFolder.standard(environment: environment).url
            let guide = mac.guide ?? folder
            return AgentPrompt(folder: folder, guide: guide, app: AgentPrompt.command(of: Bundle.main.executablePath ?? "openspot")).building(words)
        }
    }
}
