import Foundation

enum PowerCall: NounCall {
    case lidClosed
    case readings(PrintForm)

    static let noun = CommandNoun("power", group: .mac, verbs: [
        CommandVerb("lid-closed", "", "Keeps the Mac awake with its lid closed while the call runs, and prints on once it holds. The screen can still sleep and lock.", rule: CallRule(use: .power, used: "kept the Mac awake with the lid closed", inShow: .changes("keeps the Mac awake"), flags: .needsApp, needs: [.helper])) { $0.none ? Self.lidClosed : nil },
        CommandVerb("readings", "[--json]", "Prints one sample of the power of the chip as one block: watts, cpu-watts, gpu-watts, ane-watts and thermal-pressure. --json prints it as JSON.", rule: CallRule(flags: .needsApp)) { words in
            words.form.map(Self.readings)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let calls = PowerCalls(mac: context.mac.power, output: context.output)
        return switch self {
        case .lidClosed: calls.lidClosed()
        case .readings(let form): calls.readings(form)
        }
    }
}
