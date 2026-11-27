import Foundation

extension SpotsModel {
    public func card(id: String) -> Entry? {
        id == fieldSheet ? nil : entry(id)
    }

    nonisolated static let unpickedRows = 3

    struct SearchAsk {
        let query: SearchQuery
        let lists: [ItemList]
        let search: PanelSearch
        let limit: Int
        let answers: [Entry]
        let sources: [Spot]
        let isWhole: Bool

        func found() -> (matches: [(list: Int, item: SpotItem)], search: PanelSearch) {
            SearchRanks.meter?.add()
            var search = search
            return (search.matching(query, in: lists, unpickedLimit: SpotsModel.unpickedRows, limit: limit), search)
        }
    }

    public func updateVisible() {
        showDetails(shownDetails(of: query), with: showVisible)
    }

    func showVisible() {
        visibleUpdates += 1
        let text = query.trimmingCharacters(in: .whitespaces)
        if showsAttachment(of: query) {
            indexSpots()
            if slash != nil { slash = nil }
            content = .attachment
            foundSpots = []
            takeVisible(attachmentRows())
            return
        }
        guard !text.isEmpty else {
            if slash != nil { slash = nil }
            content = .cards
            foundSpots = []
            return takeVisible(cards.filter(\.isOnGrid))
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
            return takeVisible(rows)
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
            lists: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() } + [settingsBook.searchRows],
            search: panelSearch,
            limit: Self.searchLimit - answers.count,
            answers: Array(answers),
            sources: sources.map(\.spot) + [SettingsBook.searchSpot],
            isWhole: !answering.contains { sheets[$0.id]?.isAnswering == true }
        )
        takeFound(ask)
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

    private func takeFound(_ ask: SearchAsk) {
        let found = ask.found()
        panelSearch = found.search
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
        takeVisible(next)
        Set(foundSpots.compactMap { $0.item == nil ? nil : $0.spot.id }).forEach(runs.want)
        if !isEditing { missedSearch.landed(query, found: visible.contains { $0.spot.triggers.search?.isLast != true }) }
    }

    private func takeVisible(_ next: [Entry]) {
        holdsRows = false
        let isFixed = content.isFixed
        if isGridFixed != isFixed { isGridFixed = isFixed }
        let top = detailsRoom
        if isFixed, let gesture {
            let shown = Set(visible.map(\.id))
            if gesture.grid == grid, next.filter({ shown.contains($0.id) }) == visible {
                lay(gesture.layout, top: top)
                return
            }
            dropGesture()
        }
        let laid = isFixed
            ? grid.place(next.map { GridSpot(size: $0.size, cell: $0.cell(in: grid)) })
            : grid.list(next.map { $0.role == .answer && $0.size != .strip ? $0.size : grid.row })
        let shown = laid.map { next[$0.index] }
        if shown != visible { visible = shown }
        if isFixed {
            let placed = Set(shown.map(\.id))
            let left = Set(next.map(\.id)).subtracting(placed)
            if left != leftOut { leftOut = left }
            runs.take(grid: placed)
            takeOffGridSpots(placed: placed)
        }
        lay(laid.enumerated().map { $0.element.reindexed($0.offset) }, top: top)
    }

    private func lay(_ next: [SpotPlacement], top: CGFloat) {
        laidOutTop = top
        let dropped = next.map { $0.dropped(by: top) }
        if dropped != placements { placements = dropped }
    }

    func mayMove(_ id: String) -> Bool {
        guard let entry = entry(id) else { return false }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return entry.isOnGrid != (visible.contains { $0.id == id } || leftOut.contains(id))
        }
        return entry.isFound || entry.spot.triggers.lists || entry.spot.triggers.search != nil
    }

    func searchRowsChanged() {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty, content == .search else { return }
        showVisible()
    }

    func noteMiss() {
        guard let search = missedSearch.take() else { return }
        runs.usage.missed(search, at: runs.now())
    }

    func takeQuery(_ text: String) {
        hideAttachments(for: text)
        showDetails(shownDetails(of: text))
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
        form?.draft.choices?.query ?? openSheet?.query ?? query
    }

    public func search(_ text: String) {
        asOnePress {
            if form?.draft.choices != nil {
                form?.draft.search(text)
            } else if let file = SpotPackage.file(in: text) {
                takeQuery("")
                openSheet?.search("")
                DispatchQueue.main.async { self.openInStore([file]) }
            } else if let openSheet {
                openSheet.search(text)
            } else {
                takeQuery(text)
            }
        }
    }
}
