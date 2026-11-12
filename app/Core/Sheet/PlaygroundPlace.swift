import Foundation

/// A place of the panel where the playground shows a spot: its sheet, its card on the grid, or its rows in the main search.
/// Each place runs the spot as that place of the panel does (protocol: Places).
public enum PlaygroundPlace: String, CaseIterable, Sendable {
    case sheet
    case card
    case search

    public var title: String {
        rawValue.capitalized
    }

    /// The `on` line that the spot needs before this place reads it, or nil when it has one.
    public func lack(of spot: Spot) -> String? {
        switch self {
        case .sheet:
            nil
        case .card:
            spot.read?.has(.panel) == true || spot.read?.seconds != nil ? nil : "The panel reads a card with on=panel.open or on=clock.<seconds>."
        case .search:
            spot.answers == nil ? "The main search asks a spot with on=search.text <pattern>, such as on=search.text ^[0-9]." : nil
        }
    }

    /// Shows the spot of the run here with the text of the search: opens its sheet, reads it as the open panel does, or asks
    /// it the text again, also when it asked the same text before an edit.
    @MainActor
    public func show(_ run: SpotRun, query: String) {
        switch self {
        case .sheet:
            run.open {}
            if !query.isEmpty { run.search(query) }
        case .card:
            run.read(need: .change, reason: .panel)
        case .search:
            run.answer("")
            type(query, in: run)
        }
    }

    /// Takes a text typed in the search field of this place: the search of the sheet, or the main search, which asks the
    /// spot only a text that its pattern matches.
    @MainActor
    public func type(_ text: String, in run: SpotRun) {
        switch self {
        case .sheet:
            run.search(text)
        case .card:
            break
        case .search:
            let text = text.trimmingCharacters(in: .whitespaces)
            run.answer(run.spot.answers?.matches(text) == true ? text : "")
        }
    }
}
