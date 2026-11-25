import Foundation

enum TypesCall: NounCall {
    case write(spot: String?)

    static let noun = CommandNoun("types", group: .build, verbs: [
        CommandVerb(
            "", "[id]",
            "Writes the types of a .js spot to openspot.d.ts, or of a .swift spot to Openspot.swift, beside its script, with each handler, input, output, event, binding and command of its uses typed, and prints the file. With no id, it writes them for the spot of the current folder."
        ) { words in
            words.rest.count > 1 ? nil : Self.write(spot: words.rest.first)
        }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        guard case .write(let id) = self else { return nil }
        let folder = context.folder.standardizedFileURL.path + "/"
        return CommandAnswer.work { [places = context.places] in
            let spots = try places.spots.scan().scripts
            let found = id.map { id in spots.first { $0.id == id } } ?? spots.first { folder.hasPrefix($0.url.deletingLastPathComponent().standardizedFileURL.path + "/") }
            guard let spot = found else {
                throw SpotError.failed(1, id.map { "Openspot has no spot \($0). Run `openspot check spots` to see each file that does not load." } ?? "The current folder holds no spot. Run it in a spot's folder, or name the spot, such as openspot types snooze.")
            }
            let bound = Dictionary(spot.bindings.compactMap { binding in spots.first { $0.id == binding.spot }.map { (binding.name, $0) } }) { first, _ in first }
            let types = SpotTypes(spot: spot, bound: bound)
            let place = spot.url.deletingLastPathComponent()
            let file: URL
            let text: String
            switch spot.url.pathExtension {
            case "js":
                file = place.appendingPathComponent(SpotTypes.scriptFile)
                text = types.declarations
            case SwiftProgram.sourceExtension:
                file = place.appendingPathComponent(SpotTypes.swiftFile)
                text = types.swift
            default:
                throw SpotError.failed(1, "\(spot.name) is not a .js or a .swift spot, so it has no types to write.")
            }
            try text.write(to: file, atomically: true, encoding: .utf8)
            return file.path + "\n"
        }
    }
}
