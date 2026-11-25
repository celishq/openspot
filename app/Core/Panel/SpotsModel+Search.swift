import Foundation

extension SpotsModel {
    var shelfStart: Int? {
        guard isEditing, query.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let hidden = shelfCards.filter { $0.id != drag?.id }.count + (drag?.target.isOnGrid == false ? 1 : 0)
        return visible.count - hidden
    }

    var shelfCards: [Entry] {
        cards.filter { !$0.isOnGrid && $0.item == nil && $0.spot.isFound && $0.spot.fault == nil }
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

    public func card(id: String) -> Entry? {
        id == fieldSheet ? nil : entry(id)
    }

    nonisolated static let unpickedRows = 3

    struct SearchAsk {
        let query: SearchQuery
        let lists: [ItemList]
        let search: MainSearch
        let limit: Int
        let answers: [Entry]
        let sources: [Spot]
        let isWhole: Bool

        func found() -> (matches: [(list: Int, item: SpotItem)], search: MainSearch) {
            SearchRanks.meter?.add()
            var search = search
            return (search.matching(query, in: lists, unpickedLimit: SpotsModel.unpickedRows, limit: limit), search)
        }
    }

    public func updateVisible(holding motion: PanelMotion? = .edit) {
        hold(shownPreview(of: query), motion: motion)
        showVisible()
    }

    func showVisible() {
        visibleUpdates += 1
        let text = query.trimmingCharacters(in: .whitespaces)
        if showsAttachment(of: query) {
            indexSpots()
            if slash != nil { slash = nil }
            content = .attachment
            foundSpots = []
            show(attachmentRows())
            return
        }
        guard !text.isEmpty else {
            if slash != nil { slash = nil }
            content = .cards
            foundSpots = []
            return show(dragged(cards.filter(\.isOnGrid) + (isEditing ? shelfCards : [])))
        }
        indexSpots()
        let command = isEditing ? nil : SlashCommand(query)
        if command != nil, slash == nil { commands = CommandIndex(cards) }
        let rows = command.map(commandEntries) ?? []
        let next = rows.isEmpty ? nil : command
        if slash != next { slash = next }
        content = rows.isEmpty ? .search : .slash
        if !rows.isEmpty {
            foundSpots = []
            return show(rows)
        }
        var ids = Set<String>()
        let answering = entries.filter { $0.spot.triggers.search.map { runs.answerMatches.matches($0, text) } == true }
        let answers = answering
            .flatMap { entry in (sheets[entry.id]?.answers ?? []).map { Entry(spot: entry.spot, item: $0, role: .answer) } }
            .filter { ids.insert($0.id).inserted }
            .prefix(Self.searchLimit)
        let sources = entries.filter { $0.spot.triggers.lists && arrangement.isGlobal(of: $0.id) != false }
        let ask = SearchAsk(
            query: runs.search(of: text),
            lists: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() },
            search: mainSearch,
            limit: Self.searchLimit - answers.count,
            answers: Array(answers),
            sources: sources.map(\.spot),
            isWhole: !answering.contains { sheets[$0.id]?.isAnswering == true }
        )
        land(ask)
    }

    private func indexSpots() {
        guard spotListIsStale else { return }
        spotListIsStale = false
        spotListBuilds += 1
        spotList.replace(cards.filter(\.isFound).map(Self.foundItem))
        commands = CommandIndex(cards)
    }

    private static func placed(_ answers: [Entry], around found: [Entry]) -> [Entry] {
        answers.filter { $0.spot.triggers.search?.isLast != true } + found + answers.filter { $0.spot.triggers.search?.isLast == true }
    }

    private func land(_ ask: SearchAsk) {
        let found = ask.found()
        mainSearch = found.search
        let ids = Set(ask.answers.map(\.id))
        let spots = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        foundSpots = found.matches.compactMap { match in
            match.list == 0 ? spots[match.item.run] : Entry(spot: ask.sources[match.list - 1], item: match.item)
        }
        let next = Self.placed(ask.answers, around: foundSpots.filter { !ids.contains($0.id) })
        if next.isEmpty, !ask.isWhole, !visible.isEmpty {
            holdsRows = true
            return
        }
        show(next)
        Set(foundSpots.compactMap { $0.item == nil ? nil : $0.spot.id }).forEach(runs.want)
        if !isEditing { missedSearch.landed(query, found: visible.contains { $0.spot.triggers.search?.isLast != true }) }
    }

    private func show(_ next: [Entry]) {
        holdsRows = false
        if next != visible { visible = next }
        let sizes = query.isEmpty ? visible.map { $0.id == resize?.id ? resize?.size ?? $0.size : $0.size } : visible.map { $0.role == .answer ? $0.size : SpotSize.strip }
        let index = visible.firstIndex { $0.id == resize?.id }
        let grid = index.map(self.grid.keeping) ?? self.grid
        let top = fieldRoom
        if sizes != laidOutSizes || grid != laidOutGrid || top != laidOutTop {
            laidOutSizes = sizes
            laidOutGrid = grid
            laidOutTop = top
            placements = grid.place(sizes).map { $0.dropped(by: top) }
        }
        if transition.phase == .closing, !hasPlace(transition.id) { cutSheet(to: nil) }
    }

    func mayMove(_ id: String) -> Bool {
        guard let entry = entry(id) else { return false }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            guard isEditing, let index = visible.firstIndex(where: { $0.id == id }), placements.indices.contains(index) else {
                return entry.isOnGrid != visible.contains { $0.id == id }
            }
            return entry.isOnGrid == (placements[index].group == .shelf)
        }
        return entry.isFound || entry.spot.triggers.lists || entry.spot.triggers.search != nil
    }

    func noteMiss() {
        guard let search = missedSearch.take() else { return }
        runs.usage.missed(search, at: runs.now())
    }

    func takeQuery(_ text: String) {
        hold(shownPreview(of: text), motion: .edit)
        query = text
    }

    func askAnswers() {
        runs.raise(.query(query))
    }

    private static func foundItem(_ card: Entry) -> SpotItem {
        SpotItem(title: card.state.title, subtitle: [card.state.subtitle, card.spot.name].compactMap { $0 }.joined(separator: " "), run: card.id, keywords: card.spot.keywords)
    }

    func markFound(_ id: String) {
        guard !spotListIsStale else { return }
        let card = card(id: id).flatMap { $0.isFound ? Self.foundItem($0) : nil }
        if spotList.all.first(where: { $0.run == id }) != card { spotListIsStale = true }
    }

    public var searchText: String {
        get { form?.draft.choices?.query ?? openSheet?.query ?? query }
        set {
            asOnePress {
                if form?.draft.choices != nil {
                    form?.draft.search(newValue)
                } else if let file = SpotPackage.file(in: newValue) {
                    takeQuery("")
                    openSheet?.search("")
                    DispatchQueue.main.async { self.review([file]) }
                } else if let openSheet {
                    openSheet.search(newValue)
                } else {
                    takeQuery(newValue)
                }
                hideAttachments()
            }
        }
    }
}
