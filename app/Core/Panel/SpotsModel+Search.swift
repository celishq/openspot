import Foundation

extension SpotsModel {
    var shelfStart: Int? {
        guard isEditing, query.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let hidden = shelfCards.filter { $0.id != drag?.id }.count + (drag?.target.isOnGrid == false ? 1 : 0)
        return visible.count - hidden
    }

    var shelfCards: [Entry] {
        let parts = Set(cards.flatMap { $0.spot.places + ($0.spot.opens.map { [$0] } ?? []) })
        return cards.filter { !$0.isOnGrid && $0.item == nil && $0.spot.offersCard && $0.spot.fault == nil && !parts.contains($0.id) }
    }

    var grid: SpotGrid {
        var placed: [Int: GridPanel] = [:]
        let split = shelfStart
        if query.isEmpty {
            for index in visible.indices where index < (split ?? visible.count) {
                let panel = visible[index].id == drag?.id ? drag?.target.panel ?? .center : panel(of: visible[index])
                if panel != .center { placed[index] = panel }
            }
        }
        return SpotGrid(split: split, kept: Set(visible.indices.filter { visible[$0].isSizeChosen }), placed: placed, panels: panels)
    }

    public var cards: [Entry] {
        entries.filter { $0.id != fieldSheet }
    }

    public func card(id: String) -> Entry? {
        id == fieldSheet ? nil : entries.first { $0.id == id }
    }

    private static let unpickedRows = 3

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

    func mayMove(_ id: String) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }) else { return false }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            guard isEditing, let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index) else {
                return entry.isOnGrid != visible.contains { $0.id == id }
            }
            return entry.isOnGrid == (placements[index].group == .shelf)
        }
        return entry.spot.isFound || entry.spot.isGlobal || entry.spot.answers != nil
    }

    func askAnswers() {
        runs.raise(.query(query))
    }

    private func found() -> [Entry] {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            return dragged(cards.filter(\.isOnGrid) + (isEditing ? shelfCards : []))
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
        let found = mainSearch.matching(runs.search(of: text), in: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() }, unpickedLimit: Self.unpickedRows, limit: Self.searchLimit - answers.count)
        return answers + found.compactMap { match in
            match.list == 0 ? spots[match.item.run] : Entry(spot: sources[match.list - 1].spot, item: match.item)
        }.filter { !ids.contains($0.id) }
    }

    private static func foundItem(_ card: Entry) -> SpotItem {
        SpotItem(title: card.state.title, subtitle: [card.state.subtitle, card.spot.name].compactMap { $0 }.joined(separator: " "), run: card.id, keywords: card.spot.keywords)
    }

    func markFound(_ id: String) {
        guard !spotListIsStale else { return }
        let card = cards.first { $0.id == id }.flatMap { $0.spot.isFound ? Self.foundItem($0) : nil }
        if spotList.all.first(where: { $0.run == id }) != card { spotListIsStale = true }
    }

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
