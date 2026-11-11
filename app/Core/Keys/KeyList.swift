import Foundation

/// The sheet of a script that lists commands and has no read: a row for each of its commands with its key, which a person
/// records or removes. The app answers it, as a service of every such script.
public struct KeyList: Equatable, Sendable {
    private static let prefix = "key:"
    private static let clear = "clear"

    public let file: ConfigFile
    public let spot: String
    let offers: [CommandOffer]
    /// The picture of a row whose command names none.
    let picture: String

    /// Whether it answers this call: a read, or a change of a key. Any other call goes to the script.
    func answers(_ arguments: [String]) -> Bool {
        guard let first = arguments.first else { return false }
        return first == "read" || first == Self.clear || first.hasPrefix(Self.prefix)
    }

    /// Answers one call with the text a script would print. A change prints nothing, which asks for a new read.
    func answer(_ arguments: [String]) throws -> String {
        switch arguments.first {
        case "read":
            return sheet
        case Self.clear:
            if let command = arguments.dropFirst().first.flatMap(command(of:)) { try file.assign(nil, to: spot, act: .command(command)) }
            return ""
        case let run? where command(of: run) != nil:
            guard let trigger = arguments.dropFirst().first.flatMap(Trigger.init(text:)) else {
                throw SpotError.failed(1, "Openspot cannot use this key.")
            }
            try file.assign(trigger, to: spot, act: .command(command(of: run)!))
            return ""
        default:
            throw SpotError.failed(1, "This sheet cannot do that.")
        }
    }

    private var sheet: String {
        let keys = file.read().keys
        let actions = ["recents=false\n", "button=open\ntitle=Change\nclose=false\n", "button=\(Self.clear)\ntitle=Remove\nshortcut=cmd+backspace\n"]
        let rows = offers.map { offer in
            let key = keys.first { $0.spot == spot && $0.act == .command(offer.id) }
            let hides = key == nil ? "hides=\(Self.clear)\n" : ""
            return "row=\(Self.prefix)\(spot):\(offer.id)\ntitle=\(offer.title)\nicon=\(offer.icon ?? picture)\n\(hides)shortcut=\(key?.trigger.text ?? "Record")\n"
        }
        return (actions + rows).joined(separator: "\n")
    }

    /// The command that the run of a row gives a key to, when it is one of this spot's.
    private func command(of run: String) -> String? {
        guard run.hasPrefix("\(Self.prefix)\(spot):") else { return nil }
        let command = String(run.dropFirst(Self.prefix.count + spot.count + 1))
        return offers.contains { $0.id == command } ? command : nil
    }
}
