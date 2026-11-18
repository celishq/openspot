import Foundation

public enum FlowMove: Equatable, Sendable {
    case push(spot: String?, page: String?, title: String?, replace: Bool)
    case pop(all: Bool)
    case close

    init?(block: TextBlock, own: String? = nil) {
        let push = block.value(HeadKey.push).flatMap { $0 == "true" ? own : $0 }
        let spot = block.value(HeadKey.pushSpot)
        let pop = block.value(HeadKey.pop)
        switch (push != nil || spot != nil, pop) {
        case (true, nil):
            self = .push(spot: spot, page: push, title: block.value(HeadKey.pushTitle), replace: block.flag(HeadKey.pushReplace) == true)
        case (false, "true"?):
            self = .pop(all: false)
        case (false, "all"?):
            self = .pop(all: true)
        default:
            return nil
        }
    }

    init?(item block: TextBlock, own: String) {
        if let route = block.value(RowKey.route) {
            self = .push(spot: nil, page: route, title: block.value(RowKey.routeTitle), replace: block.flag(RowKey.routeReplace) == true)
        } else if let move = FlowMove(block: block, own: own), case .push = move {
            self = move
        } else {
            return nil
        }
    }
}
