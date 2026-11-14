import Foundation

extension SpotRun {
    struct PageState {
        let state: SpotState
        let rows: ItemList
        let panel: SheetParts?
    }

    public func show(page next: String?) {
        guard next != page else { return }
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
        if showsSheet { read(need: .change, reason: .sheet) }
    }

    func forget(page: String?) {
        pageStates.removeAll { $0.page == page }
    }

    func withPage(_ variables: [String: String]) -> [String: String] {
        guard let page else { return variables }
        return variables.merging(["OPENSPOT_PAGE": page]) { _, own in own }
    }
}
