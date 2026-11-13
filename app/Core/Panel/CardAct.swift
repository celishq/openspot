import Foundation

/// What the API can do to the card of a spot, as its row in the actions menu does: open its file in the text editor, copy a
/// prompt for an agent to change it, share it, or delete it so that `⌘Z` puts it back.
public enum CardAct: String, Equatable, Sendable, CaseIterable {
    case edit
    case prompt
    case share
    case delete
}
