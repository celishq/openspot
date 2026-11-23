import Foundation

public enum FlowMove: Equatable, Sendable {
    case push(spot: String?, route: String?, title: String?, replace: Bool)
    case pop(all: Bool)
    case close

    init?(item block: TextBlock) {
        guard let route = block.value(ItemKey.route) else { return nil }
        self = .push(spot: nil, route: route, title: block.value(ItemKey.routeTitle), replace: block.flag(ItemKey.routeReplace) == true)
    }
}
