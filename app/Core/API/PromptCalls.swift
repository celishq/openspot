import Foundation

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
