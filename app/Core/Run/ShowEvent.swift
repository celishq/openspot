import Foundation

public enum ShowEvent: Equatable, Sendable {
    case panel
    case sheet
    case want
    case change
    case clock
    case typed(String, inSheet: Bool)
    case event(String, value: String?)

    static let options = [ShowEvent.panel, .sheet, .want, .change].map(\.name)

    var name: String {
        switch self {
        case .panel: EventName.panelOpen
        case .sheet: EventName.sheetOpen
        case .want: EventName.spotWant
        case .change: EventName.spotChange
        case .clock: "clock"
        case .typed(_, let inSheet): inSheet ? EventName.sheetText : EventName.searchText
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
            guard let search, !search.text.isEmpty else { return ScriptEntry.every.message(after: given) }
            return ScriptEntry.sheetText.message([search.text], search.forms, after: given)
        case .typed(let text, let inSheet):
            return (inSheet ? ScriptEntry.sheetText : ScriptEntry.search).message([text], search?.forms ?? [], after: given)
        case .event(let name, let value) where !Self.options.contains(name):
            return ScriptEntry.event(name).message(value.map { [$0] } ?? [], after: given)
        default:
            return ScriptEntry.show.message([name], after: given)
        }
    }
}
