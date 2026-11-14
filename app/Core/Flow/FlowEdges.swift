import Foundation

public struct FlowEdges: Equatable, Sendable {
    public private(set) var edges: [FlowEdge] = []
    public private(set) var shown: FlowSheet?
    public private(set) var from: CGRect?
    public private(set) var coming: FlowEdge.Side?

    public init() {}

    init(flow: Flow, title: (FlowSheet) -> String) {
        let behind = flow.pages.prefix(max(flow.index, 0)).reversed().prefix(SpotTokens.edgeCount)
        let ahead = flow.pages.dropFirst(flow.index + 1).prefix(SpotTokens.edgeCount)
        edges = behind.enumerated().map { FlowEdge(sheet: $0.element, title: title($0.element), place: .bar(.behind, $0.offset)) }
            + ahead.enumerated().map { FlowEdge(sheet: $0.element, title: title($0.element), place: .bar(.ahead, $0.offset)) }
        shown = flow.current
    }

    public func titles(on side: FlowEdge.Side) -> [String] {
        edges.filter { !$0.isFading && $0.place.side == side }.map(\.title)
    }

    func standing(at rect: CGRect, title: String, in flow: Flow) -> FlowEdges {
        var next = settled
        guard let shown, !next.edges.contains(where: { $0.sheet == shown }) else { return next }
        let left = flow.pages.firstIndex(of: shown) ?? -1
        next.coming = left > flow.index ? .behind : .ahead
        next.edges.append(FlowEdge(sheet: shown, title: title, place: .stand(rect)))
        next.from = rect
        return next
    }

    func moved(to rest: FlowEdges) -> FlowEdges {
        var next = rest
        next.from = from
        next.coming = coming
        for edge in edges where !rest.edges.contains(where: { $0.sheet == edge.sheet }) {
            var gone = edge
            if edge.sheet == rest.shown { gone.place = .sheet }
            gone.isFading = true
            next.edges.append(gone)
        }
        return next
    }

    var settled: FlowEdges {
        var next = self
        next.edges.removeAll(where: \.isFading)
        next.from = nil
        next.coming = nil
        return next
    }
}

extension FlowEdge.Place {
    public var side: FlowEdge.Side? {
        if case .bar(let side, _) = self { return side }
        return nil
    }
}
