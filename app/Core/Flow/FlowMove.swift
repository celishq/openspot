import Foundation

public enum FlowMove: Equatable, Sendable {
    case push(spot: String?, route: String?, title: String?, replace: Bool)
    case pop(all: Bool)
    case close
    case session(String)

    init?(item block: TextBlock) {
        if let id = block.value(ItemKey.session) {
            self = .session(id)
            return
        }
        guard let route = block.value(ItemKey.route) else { return nil }
        self = .push(spot: nil, route: route, title: block.value(ItemKey.routeTitle), replace: block.flag(ItemKey.routeReplace) == true)
    }
}
