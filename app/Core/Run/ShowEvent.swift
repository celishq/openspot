import Foundation

public enum ShowEvent: Equatable, Sendable {
    case panel
    case sheet
    case want
    case change
    case clock
    case typed(String, inSheet: Bool)
    case event(String, value: String?)

    static let moments = [ShowEvent.panel, .sheet, .want, .change].map(\.name)

    var name: String {
        switch self {
        case .panel: SpotEvent.panelOpen
        case .sheet: SpotEvent.sheetOpen
        case .want: SpotEvent.spotWant
        case .change: "spot.change"
        case .clock: "clock"
        case .typed(_, let inSheet): inSheet ? SpotEvent.sheetText : SpotEvent.searchText
        case .event(let name, _): name
        }
    }

    var isEvent: Bool {
        if case .event = self { true } else { false }
    }

    var isFrequent: Bool {
        switch self {
        case .want, .clock, .typed, .event: true
        default: false
        }
    }

    func message(after given: [TextBlock.Field] = [], search: SearchQuery? = nil) -> Message {
        switch self {
        case .clock:
            guard let search, !search.text.isEmpty else { return Handler.every.message(after: given) }
            return Handler.sheetText.message([search.text], search.forms, after: given)
        case .typed(let text, let inSheet):
            return (inSheet ? Handler.sheetText : Handler.search).message([text], search?.forms ?? [], after: given)
        case .event(let name, let value) where !Self.moments.contains(name):
            return Handler.event(name).message(value.map { [$0] } ?? [], after: given)
        default:
            return Handler.show.message([name], after: given)
        }
    }
}
