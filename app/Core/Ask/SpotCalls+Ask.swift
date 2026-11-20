import Foundation

extension SpotCalls {
    func ask(_ id: String) -> CommandAPI.Work {
        guard let app, let runs else { return CommandAnswer.notRunning("spot ask \(id)") }
        if caller?.id == id {
            return { CommandAnswer(errors: "A spot cannot ask itself. Ask another spot, such as `openspot spot ask snooze`.\n", code: 1) }
        }
        return {
            guard await app.ask(id, from: caller?.id) else {
                return CommandAnswer(errors: "Openspot has no spot `\(id)`. Run `openspot spot list` to see each one.\n", code: 1)
            }
            guard let value = await runs.ask(id) else { return CommandAnswer(code: 1) }
            return CommandAnswer(output: value + "\n")
        }
    }

    func reply(_ value: String) -> CommandAPI.Work {
        guard let runs else { return CommandAnswer.notRunning("spot reply") }
        guard let id = caller?.id else {
            return { CommandAnswer(errors: "`openspot spot reply` runs only from a spot that `spot ask` opened.\n", code: 1) }
        }
        return {
            await runs.reply(value, from: id) ? CommandAnswer() : CommandAnswer(errors: "No `spot ask` waits for \(id). Reply only while a `spot ask` waits for the spot.\n", code: 1)
        }
    }
}
