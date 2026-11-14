import Foundation

public enum Place: String, CaseIterable, Sendable {
    case card, search, menubar, float, window

    private static let none = "none"

    static func read(_ lines: [String], of name: String) throws -> Set<Place>? {
        guard !lines.isEmpty else { return nil }
        if lines.contains(none) {
            guard lines == [none] else { throw SpotError.fault("\(name) offers none and another place. Keep offers=none alone, or remove it") }
            return []
        }
        return try Set(lines.map { line in
            let word = line.trimmingCharacters(in: .whitespaces)
            if word.contains(",") {
                throw SpotError.fault("\(name) has offers=\(word). Write one place on each line, such as offers=card and offers=search")
            }
            if word == "actions" {
                throw SpotError.fault("\(name) offers actions in its header. Write offers=actions on a button, such as after button=change")
            }
            if word == "rows" {
                throw SpotError.fault("\(name) offers rows, which Openspot no longer reads. Use offers=search, and leave out offers=card")
            }
            guard let place = Place(rawValue: word) else {
                throw SpotError.fault("\(name) offers an unknown place: \(word). Use card, search, menubar, float, window or none")
            }
            return place
        })
    }

    static func check(_ places: Set<Place>, read: SpotRead?, mode: SpotMode, kind: SpotKind, of name: String) throws {
        if places.contains(.search), read?.has(.panel) != true, read?.has(.sheet) != true, read?.seconds == nil {
            throw SpotError.fault("\(name) needs on=panel.open, on=sheet.open or a clock, such as on=clock.60, to join the main search")
        }
        if places.contains(.float), kind != .list {
            throw SpotError.fault("\(name) offers float, which needs a sheet. Add on=sheet.open, or remove offers=float")
        }
        if places.contains(.window), kind != .list {
            throw SpotError.fault("\(name) offers window, which needs a sheet. Add on=sheet.open, or remove offers=window")
        }
        if places.contains(.menubar), read?.seconds == nil, read?.hasEvent != true, !mode.stays {
            throw SpotError.fault("\(name) offers menubar, which needs a clock, an event or mode=stay, such as on=clock.60")
        }
    }
}
