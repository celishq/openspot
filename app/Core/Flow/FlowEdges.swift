import Foundation

public struct FlowEdges: Equatable, Sendable {
    struct Stand: Equatable, Sendable {
        let from: CGRect
        let coming: FlowEdge.Side
        let leaving: FlowEdge.Place
        let sheet: FlowSheet
        let page: SheetPage?
    }

    enum Step: Equatable, Sendable {
        case rest
        case standing(Stand, start: FlowEdge.Place, onMark: Bool)
        case moving(Stand?)
    }

    public private(set) var edges: [FlowEdge] = []
    public private(set) var shown: FlowSheet?
    private(set) var step = Step.rest

    private var stand: Stand? {
        switch step {
        case .rest: nil
        case .standing(let stand, _, _): stand
        case .moving(let stand): stand
        }
    }

    public var from: CGRect? {
        stand?.from
    }

    public var coming: FlowEdge.Side? {
        stand?.coming
    }

    public var leaving: FlowEdge.Place? {
        stand?.leaving
    }

    public var leavingSheet: FlowSheet? {
        stand?.sheet
    }

    public var leavingPage: SheetPage? {
        stand?.page
    }

    public var isMoving: Bool {
        if case .moving = step { return true }
        return false
    }

    public var sheetStart: FlowEdge.Place? {
        if case .standing(_, let start, _) = step { return start }
        return nil
    }

    public var sheetStartsOnMark: Bool {
        if case .standing(_, _, let onMark) = step { return onMark }
        return false
    }

    public init() {}

    init(flow: Flow, title: (FlowSheet) -> String) {
        let behind = flow.pages.prefix(max(flow.index, 0)).reversed().prefix(SpotTokens.edgeCount)
        let ahead = flow.pages.dropFirst(flow.index + 1).prefix(SpotTokens.edgeCount)
        edges = behind.enumerated().map { FlowEdge(sheet: $0.element, title: title($0.element), place: .bar(.behind, $0.offset)) }
            + ahead.enumerated().map { FlowEdge(sheet: $0.element, title: title($0.element), place: .bar(.ahead, $0.offset)) }
        shown = flow.current
    }

    public func room(around sheetRect: CGRect) -> CGRect {
        isMoving ? sheetRect : from ?? sheetRect
    }

    public func heldHeight(of sheetRect: CGRect) -> CGFloat {
        room(around: sheetRect).height - sheetRect.height
    }

    public var leavingEdge: FlowEdge? {
        edges.first { $0.sheet == leavingSheet }
    }

    public func titles(on side: FlowEdge.Side) -> [String] {
        edges.filter { !$0.isFading && $0.place.side == side }.map(\.title)
    }

    func standing(at rect: CGRect, holding page: SheetPage?, in flow: Flow, title: (FlowSheet) -> String) -> FlowEdges {
        var next = settled
        guard let shown, !next.edges.contains(where: { $0.sheet == shown }) else { return next }
        let left = flow.pages.firstIndex(of: shown)
        let coming: FlowEdge.Side = left.map { $0 > flow.index ? .behind : .ahead } ?? .behind
        let onMark = next.edges.contains { $0.sheet == flow.current }
        next.edges.removeAll { $0.sheet == flow.current }
        next.edges.append(FlowEdge(sheet: shown, title: title(shown), place: .stand(rect)))
        let leaving: FlowEdge.Place = left == nil ? .line(.ahead) : .bar(coming == .ahead ? .behind : .ahead, 0)
        next.step = .standing(Stand(from: rect, coming: coming, leaving: leaving, sheet: shown, page: page), start: .bar(coming, 0), onMark: onMark)
        return next
    }

    func moved(to rest: FlowEdges) -> FlowEdges {
        var next = rest
        next.step = .moving(stand)
        for edge in edges where !rest.edges.contains(where: { $0.sheet == edge.sheet }) {
            var gone = edge
            if edge.sheet == leavingSheet, let leaving { gone.place = leaving }
            gone.isFading = true
            next.edges.append(gone)
        }
        return next
    }

    var settled: FlowEdges {
        var next = self
        next.edges.removeAll(where: \.isFading)
        next.step = .rest
        return next
    }
}

extension FlowEdge.Place {
    public var side: FlowEdge.Side? {
        if case .bar(let side, _) = self { return side }
        return nil
    }
}
