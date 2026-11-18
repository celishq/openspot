import Foundation

public enum Place: String, CaseIterable, Sendable {
    case search

    static func read(_ lines: [String], of name: String) throws -> Set<Place> {
        try Set(lines.map { line in
            let word = line.trimmingCharacters(in: .whitespaces)
            if word == OfferedAction.place {
                throw SpotError.fault("\(name) offers actions at its top level. Write offers = [\"actions\"] on a command, such as in [commands.change]")
            }
            guard let place = Place(rawValue: word) else {
                throw SpotError.fault("\(name) offers an unknown place: \(word). Use search")
            }
            return place
        })
    }

    static func check(_ places: Set<Place>, read: SpotRead?, of name: String) throws {
        if places.contains(.search), read?.has(.panel) != true, read?.has(.sheet) != true, read?.seconds == nil {
            throw SpotError.fault("\(name) needs on=panel.open, on=sheet.open or a clock, such as on=clock.60, to join the main search")
        }
    }
}
