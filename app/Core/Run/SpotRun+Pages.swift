import Foundation

extension SpotRun {
    struct PageState {
        let state: SpotState
        let rows: ItemList
        let panel: SheetParts?
    }

    @discardableResult
    public func show(_ next: FlowSheet) -> Bool {
        let shown = page
        if next.title != shown.title || next.source != shown.source { page = next }
        guard next.route != shown.route else { return true }
        let route = shown.route
        forget(route: route)
        pageStates.append((route, PageState(state: state, rows: rows, panel: panel)))
        if let show = running(Self.showKey) { stop(show) }
        if let search = running(Self.searchKey) { stop(search) }
        page = next
        let kept = pageStates.first { $0.route == next.route }?.state
        forget(route: next.route)
        state = kept?.state ?? spot.headerState
        list = kept?.rows ?? ItemList(recent: rows.recent, search: rows.search)
        panel = kept?.panel
        answered = nil
        lastAnswer = nil
        shownFrame = nil
        if showsSheet { show(need: .change, event: .sheet) }
        return kept != nil
    }

    func holdPageMotion(start: @escaping () -> Void) {
        guard answered == nil else { return start() }
        runs.opening.holdMotion(of: spot.id, limited: true, start: start)
    }

    func forget(route: String?) {
        pageStates.removeAll { $0.route == route }
    }

    func message(of call: Call, values: FieldValues) -> Message {
        var message = call.message
        message.event = call.event
        message.route = route
        message.settings = values.settings
        return spot.takesHandlers ? message.handled() : message
    }

    var fieldValues: FieldValues {
        FieldValues(of: spot, in: runs.settings, secrets: runs.secrets?.values(of: spot.id) ?? [:])
    }
}
