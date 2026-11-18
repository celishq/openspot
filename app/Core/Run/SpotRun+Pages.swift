import Foundation

extension SpotRun {
    struct PageState {
        let state: SpotState
        let rows: ItemList
        let panel: SheetParts?
    }

    @discardableResult
    public func show(page next: String?) -> Bool {
        guard next != page else { return true }
        forget(page: page)
        pageStates.append((page, PageState(state: state, rows: rows, panel: panel)))
        if let read = running(Self.readKey) { stop(read) }
        if let search = running(Self.searchKey) { stop(search) }
        page = next
        let kept = pageStates.first { $0.page == next }?.state
        forget(page: next)
        state = kept?.state ?? spot.headerState
        list = kept?.rows ?? ItemList(recent: rows.recent, search: rows.search)
        panel = kept?.panel
        answered = nil
        lastAnswer = nil
        shownFrame = nil
        if showsSheet { read(need: .change, reason: .sheet) }
        return kept != nil
    }

    func holdPageMotion(start: @escaping () -> Void) {
        guard answered == nil else { return start() }
        runs.opening.holdMotion(of: spot.id, limited: true, start: start)
    }

    func forget(page: String?) {
        pageStates.removeAll { $0.page == page }
    }

    func message(of call: Call, values: FieldValues) -> Message {
        var message = call.message
        message.event = call.reason
        message.route = page
        message.settings = values.settings
        return message
    }

    var fieldValues: FieldValues {
        FieldValues(of: spot, in: runs.settings, secrets: runs.secrets?.values(of: spot.id) ?? [:])
    }
}
