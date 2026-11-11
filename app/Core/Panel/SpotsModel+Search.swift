import Foundation

/// The main search: the cards that its text finds, with the rows and the answers that join them.
extension SpotsModel {
    /// The entries that have a card. A sheet that grows out of the field, such as the install screen, has none.
    public var cards: [Entry] {
        entries.filter { $0.id != fieldSheet }
    }

    /// The most rows that the main search shows from a list that the person never picked from.
    private static let unpickedRows = 3

    /// Shows the spots that the search finds and the items it finds in the lists that offer them, in one ranking.
    public func updateVisible() {
        let next = found()
        if next != visible { visible = next }
        let sizes = visible.map { $0.id == resize?.id ? resize?.size ?? $0.size : $0.size }
        if sizes != laidOutSizes {
            laidOutSizes = sizes
            placements = SpotGrid().place(sizes)
        }
        if transition.phase == .closing, !hasPlace(transition.id) { cutSheet(to: nil) }
    }

    /// Raises the text of the main search, which each spot whose `answers` pattern matches answers (A2).
    func askAnswers() {
        runs.raise(.query(query))
    }

    /// The cards that the search finds, or each card on the grid when there is no search. The rows that spots give as
    /// answers to the text come first (A3).
    private func found() -> [Entry] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            let arriving = carry.flatMap { $0.tile != nil && drag?.id == $0.entry.id ? [$0.entry] : nil } ?? []
            return dragged(cards.filter(\.isOnGrid) + arriving + (isEditing ? cards.filter { !$0.isOnGrid } : []))
        }
        var ids = Set<String>()
        let answers = entries.filter { $0.spot.answers.map { runs.answerMatches.matches($0, text) } == true }
            .flatMap { entry in (sheets[entry.id]?.answers ?? []).map { Entry(spot: entry.spot, item: $0, isAnswer: true) } }
            .filter { ids.insert($0.id).inserted }
            .prefix(Self.searchLimit)
        let spots = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        if spotListIsStale {
            spotListIsStale = false
            spotListBuilds += 1
            spotList.replace(cards.filter(\.spot.isFound).map { SpotItem(title: $0.state.title, subtitle: [$0.state.subtitle, $0.spot.name].compactMap { $0 }.joined(separator: " "), run: $0.id) })
        }
        let sources = entries.filter { $0.spot.isGlobal && arrangement.isGlobal(of: $0.id) != false }
        let found = mainSearch.matching(SearchQuery(text: text), in: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() }, unpickedLimit: Self.unpickedRows, limit: Self.searchLimit - answers.count)
        return answers + found.compactMap { match in
            match.list == 0 ? spots[match.item.run] : Entry(spot: sources[match.list - 1].spot, item: match.item)
        }.filter { !ids.contains($0.id) }
    }

    /// The text of the field: the search of the open list, or else the search of the spots.
    public var searchText: String {
        get { form?.draft.choices?.query ?? openItems?.query ?? query }
        set {
            if form?.draft.choices != nil {
                form?.draft.search(newValue)
            } else if let file = SharedSpot.file(in: newValue) {
                query = ""
                openSheet?.search("")
                DispatchQueue.main.async { self.review([file]) }
            } else if let openSheet {
                openSheet.search(newValue)
            } else {
                query = newValue
            }
        }
    }
}
