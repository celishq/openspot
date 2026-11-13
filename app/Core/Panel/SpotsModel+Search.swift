import Foundation

/// The main search: the cards that its text finds, with the rows and the answers that join them.
extension SpotsModel {
    /// The grid of the cards shown, with the size of each card whose size the person chose, and of a card that arrives from
    /// the store.
    var grid: SpotGrid {
        let arriving = carry?.tile == nil ? nil : carry?.entry.id
        let placed = query.isEmpty ? Dictionary(uniqueKeysWithValues: visible.indices.compactMap { index in
            visible[index].side == .center ? nil : (index, visible[index].side)
        }) : [:]
        return SpotGrid(kept: Set(visible.indices.filter { visible[$0].isSizeChosen || visible[$0].id == arriving }), placed: placed, sides: sides)
    }

    /// The entries that have a card. A sheet that grows out of the field, such as the install screen, has none.
    public var cards: [Entry] {
        entries.filter { $0.id != fieldSheet }
    }

    /// The entry with a card that has this ID, found with no copy of the cards.
    public func card(id: String) -> Entry? {
        id == fieldSheet ? nil : entries.first { $0.id == id }
    }

    /// The most rows that the main search shows from a list that the person never picked from.
    private static let unpickedRows = 3

    /// Shows the spots that the search finds and the items it finds in the lists that offer them, in one ranking. While the
    /// search has text, each one is a full-width row, and an answer card keeps its own full-width size (protocol: Places).
    public func updateVisible() {
        visibleUpdates += 1
        let next = found()
        if next != visible { visible = next }
        let sizes = query.isEmpty ? visible.map { $0.id == resize?.id ? resize?.size ?? $0.size : $0.size } : visible.map { $0.isAnswer ? $0.size : SpotSize.strip }
        let index = visible.firstIndex { $0.id == resize?.id }
        let grid = index.map(self.grid.keeping) ?? self.grid
        if sizes != laidOutSizes || grid != laidOutGrid {
            laidOutSizes = sizes
            laidOutGrid = grid
            placements = grid.place(sizes)
        }
        if transition.phase == .closing, !hasPlace(transition.id) { cutSheet(to: nil) }
    }

    /// Whether a change of the rows or the state of a spot can change the cards that show: with no search, when it moves its
    /// card on or off the grid, and with a search, when the search finds the spot, its rows or its answers.
    func mayMove(_ id: String) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }) else { return false }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return entry.isOnGrid != visible.contains { $0.id == id } }
        return entry.spot.isFound || entry.spot.isGlobal || entry.spot.answers != nil
    }

    /// Raises the text of the main search, which each spot whose `answers` pattern matches answers (protocol: Places).
    func askAnswers() {
        runs.raise(.query(query))
    }

    /// The cards that the search finds, or each card on the grid when there is no search. The rows that spots give as
    /// answers to the text come first (protocol: Places).
    private func found() -> [Entry] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            let arriving = carry.flatMap { $0.tile != nil && drag?.id == $0.entry.id ? [$0.entry] : nil } ?? []
            return dragged(cards.filter(\.isOnGrid) + arriving)
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
            spotList.replace(cards.filter(\.spot.isFound).map(Self.foundItem))
        }
        let sources = entries.filter { $0.spot.isGlobal && arrangement.isGlobal(of: $0.id) != false }
        let found = mainSearch.matching(SearchQuery(text: text), in: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() }, unpickedLimit: Self.unpickedRows, limit: Self.searchLimit - answers.count)
        return answers + found.compactMap { match in
            match.list == 0 ? spots[match.item.run] : Entry(spot: sources[match.list - 1].spot, item: match.item)
        }.filter { !ids.contains($0.id) }
    }

    /// The item that the main search finds for a card.
    private static func foundItem(_ card: Entry) -> SpotItem {
        SpotItem(title: card.state.title, subtitle: [card.state.subtitle, card.spot.name].compactMap { $0 }.joined(separator: " "), run: card.id, keywords: card.spot.keywords)
    }

    /// Marks `spotList` stale when the searched text of this card differs from its item there.
    func markFound(_ id: String) {
        guard !spotListIsStale else { return }
        let card = cards.first { $0.id == id }.flatMap { $0.spot.isFound ? Self.foundItem($0) : nil }
        if spotList.all.first(where: { $0.run == id }) != card { spotListIsStale = true }
    }

    /// The text of the field: the search of the open list, or else the search of the spots.
    public var searchText: String {
        get { form?.draft.choices?.query ?? openSheet?.query ?? query }
        set {
            if form?.draft.choices != nil {
                form?.draft.search(newValue)
            } else if let file = SpotPackage.file(in: newValue) {
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
