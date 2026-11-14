import Foundation

/// The pages of a run: one sheet of the script at a time, each named to the script in `OPENSPOT_PAGE`, and what each page
/// last showed, kept while another page shows.
extension SpotRun {
    /// What a page showed when another page took its place.
    struct KeptPage {
        let state: SpotState
        let rows: ItemList
        let panel: SheetParts?
    }

    /// Shows another page of the sheet. It keeps what this page shows, stops its reads, shows what the next page last showed,
    /// or nothing, and reads that page when the sheet is open.
    public func show(page next: String?) {
        guard next != page else { return }
        keptPages.removeAll { $0.page == page }
        keptPages.append((page, KeptPage(state: state, rows: rows, panel: panel)))
        if keptPages.count > SheetHistory.limit { keptPages.removeFirst(keptPages.count - SheetHistory.limit) }
        if let read = running(Self.readKey) { stop(read) }
        if let search = running(Self.searchKey) { stop(search) }
        page = next
        let kept = keptPages.first { $0.page == next }?.kept
        state = kept?.state ?? spot.headerState
        list = kept?.rows ?? ItemList(recent: rows.recent, search: rows.search)
        panel = kept?.panel
        answered = nil
        lastAnswer = nil
        if showsSheet { read(need: .change, reason: .sheet) }
    }

    /// The variables of a call with the page that shows added.
    func withPage(_ variables: [String: String]) -> [String: String] {
        guard let page else { return variables }
        return variables.merging(["OPENSPOT_PAGE": page]) { _, own in own }
    }
}
