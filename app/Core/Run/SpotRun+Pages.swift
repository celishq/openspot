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

    func sent(_ variables: [String: String], values: FieldValues) -> [String: String] {
        let given = values.variables.merging(variables) { _, given in given }
        guard let page else { return given }
        return given.merging(["OPENSPOT_PAGE": page]) { _, own in own }
    }

    var fieldValues: FieldValues {
        FieldValues(of: spot, in: runs.settings, secrets: runs.secrets?.values(of: spot.id) ?? [:])
    }
}
