import Foundation

struct HelpCalls {
    func list() -> CommandAPI.Work {
        { CommandAnswer(output: CommandLineCall.usage) }
    }

    func guide(of noun: String) -> CommandAPI.Work {
        CommandAnswer.work {
            guard let folder = Bundle.main.url(forResource: "Help", withExtension: nil) else { throw SpotError.fault("This copy of Openspot has no guides. Install Openspot again.") }
            return try CommandGuide(folder: folder).text(of: noun)
        }
    }
}
