import Foundation

extension SpotsModel {
    func openContext() {
        let front = isWarming ? nil : host.frontApp
        let feeds = !isWarming && entries.contains { entry in ContextValue.Kind.allCases.contains(where: entry.spot.takes) }
        let loading = feeds ? entries.filter { $0.spot.uses.contains(.context) && $0.spot.triggers.opensOverAnApp && $0.spot.triggers.opens(over: front) }.map(\.id) : []
        var next = context
        next.open(over: front, loading: loading)
        if next != context { context = next }
        runs.panelOpened(showsToEnd: isWarming, over: front, feedsContext: feeds)
    }

    func takeContext(_ value: ContextValue, of id: String) {
        var next = context
        if cards.contains(where: { $0.spot.takes(value) }) { next.fill(id, with: value) } else { next.remove(id) }
        if next != context { context = next }
    }

    func endContext(of id: String) {
        var next = context
        next.end(id)
        if next != context { context = next }
    }
}
