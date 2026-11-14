import Foundation

/// A move of a flow that a spot asks for: a push of a sheet over the one that shows, or a pop of its own sheet
/// (protocol: Pages).
public enum SheetMove: Equatable, Sendable {
    /// A sheet of `spot`, or of the spot that asks when nil, at `page`, or its first sheet when nil. With `replace`, it takes
    /// the place of the sheet that shows.
    case push(spot: String?, page: String?, title: String?, replace: Bool)
    /// The sheet that shows, or with `all` each page of the spot back to its first sheet.
    case pop(all: Bool)

    /// The move that a block's `push` and `pop` keys ask for, or nil for none or for both. `push=true` stands for `own`.
    init?(block: TextBlock, own: String? = nil) {
        let push = block.value("push").flatMap { $0 == "true" ? own : $0 }
        let spot = block.value("push.spot")
        let pop = block.value("pop")
        switch (push != nil || spot != nil, pop) {
        case (true, nil):
            self = .push(spot: spot, page: push, title: block.value("push.title"), replace: block.flag("push.replace") == true)
        case (false, "true"?):
            self = .pop(all: false)
        case (false, "all"?):
            self = .pop(all: true)
        default:
            return nil
        }
    }
}
