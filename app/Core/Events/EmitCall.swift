import Foundation

enum EmitCall: NounCall {
    case emit(event: String, values: [TextBlock.Field])

    static let noun = CommandNoun("emit", group: .build, verbs: [
        CommandVerb(
            "", "<event> [<name>=<value>...]",
            "Sends one of the [events] of the calling spot, with its values checked. Each spot that binds it and lists <binding>.<event> in its [on] gets a call of that handler. It runs only in a run of a spot."
        ) { words in
            guard let event = words.rest.first else { return nil }
            do {
                return Self.emit(event: event, values: try Manifest.InputCheck.fields(of: Array(words.rest.dropFirst()), as: .value))
            } catch {
                return CallFault.refused(SpotRuns.reason(error))
            }
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .emit(let name, let given) = self else { return nil }
        guard let runs = context.runs, let spot = context.channel else {
            return { CommandAnswer(errors: "`openspot emit` \(RunCall.channelOnly)\n", code: 2) }
        }
        guard let event = spot.events.first(where: { $0.name == name }) else {
            return { CommandAnswer(errors: "\(spot.name) has no event \(name). Declare it in [events.\(name)] of its spot.toml.\n", code: 2) }
        }
        let values: [TextBlock.Field]
        do {
            values = try event.check.checked(given)
        } catch {
            return { CommandAnswer(errors: SpotRuns.reason(error) + "\n", code: 2) }
        }
        return {
            await runs.emit(name, values: values, from: spot)
            return CommandAnswer()
        }
    }
}
