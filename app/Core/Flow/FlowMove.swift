import Foundation

public enum FlowMove: Equatable, Sendable {
    case push(spot: String?, page: String?, title: String?, replace: Bool)
    case pop(all: Bool)
    case close

    init?(item block: TextBlock) {
        guard let route = block.value(RowKey.route) else { return nil }
        self = .push(spot: nil, page: route, title: block.value(RowKey.routeTitle), replace: block.flag(RowKey.routeReplace) == true)
    }
}
