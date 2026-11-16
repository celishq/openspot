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

    public func card(id: String) -> Entry? {
        id == fieldSheet ? nil : entry(id)
    }

    nonisolated static let unpickedRows = 3

    struct SearchAsk: Sendable {
        let query: SearchQuery
        let lists: [ItemList]
        let search: MainSearch
        let limit: Int

        func found() -> (matches: [(list: Int, item: SpotItem)], search: MainSearch) {
            SearchRanks.meter?.add()
            var search = search
            return (search.matching(query, in: lists, unpickedLimit: SpotsModel.unpickedRows, limit: limit), search)
        }
    }

    struct Finding {
        let ask: SearchAsk
        let answers: [Entry]
        let sources: [Spot]
        let job: Task<Void, Never>
    }

    public func updateVisible() {
        visibleUpdates += 1
        finding?.job.cancel()
        finding = nil
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            if slash != nil { slash = nil }
            foundSpots = []
            return show(dragged(cards.filter(\.isOnGrid) + (isEditing ? shelfCards : [])))
        }
        if spotListIsStale {
            spotListIsStale = false
            spotListBuilds += 1
            spotList.replace(cards.filter(\.spot.isFound).map(Self.foundItem))
            commands = CommandIndex(cards)
        }
        let command = isEditing ? nil : SlashCommand(query)
        let rows = command.map(commandEntries) ?? []
        let next = rows.isEmpty ? nil : command
        if slash != next { slash = next }
        if !rows.isEmpty {
            foundSpots = []
            return show(rows)
        }
        var ids = Set<String>()
        let answers = entries.filter { $0.spot.answers.map { runs.answerMatches.matches($0, text) } == true }
            .flatMap { entry in (sheets[entry.id]?.answers ?? []).map { Entry(spot: entry.spot, item: $0, isAnswer: true) } }
            .filter { ids.insert($0.id).inserted }
            .prefix(Self.searchLimit)
        let sources = entries.filter { $0.spot.isGlobal && arrangement.isGlobal(of: $0.id) != false }
        let ask = SearchAsk(
            query: runs.search(of: text),
            lists: [spotList] + sources.map { sheets[$0.id]?.list ?? ItemList() },
            search: mainSearch,
            limit: Self.searchLimit - answers.count
        )
        let job = Task { [weak self] in
            let found = await Self.found(ask)
            guard let found, !Task.isCancelled, let self, let finding = self.finding else {
                SearchRanks.meter?.drop()
                return
            }
            self.finding = nil
            land(found, of: finding)
        }
        finding = Finding(ask: ask, answers: Array(answers), sources: sources.map(\.spot), job: job)
        if !answers.isEmpty || visible.contains(where: \.isAnswer) { show(answers + foundSpots.filter { !ids.contains($0.id) }) }
    }

    @concurrent
    private nonisolated static func found(_ ask: SearchAsk) async -> (matches: [(list: Int, item: SpotItem)], search: MainSearch)? {
        Task.isCancelled ? nil : ask.found()
    }

    public func landSearch() {
        guard let finding else { return }
        finding.job.cancel()
        self.finding = nil
        land(finding.ask.found(), of: finding)
    }

    private func land(_ found: (matches: [(list: Int, item: SpotItem)], search: MainSearch), of finding: Finding) {
        mainSearch = found.search
        let ids = Set(finding.answers.map(\.id))
        let spots = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        foundSpots = found.matches.compactMap { match in
            match.list == 0 ? spots[match.item.run] : Entry(spot: finding.sources[match.list - 1], item: match.item)
        }
        show(finding.answers + foundSpots.filter { !ids.contains($0.id) })
    }

    private func show(_ next: [Entry]) {
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
        guard let entry = entry(id) else { return false }
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

    private static func foundItem(_ card: Entry) -> SpotItem {
        SpotItem(title: card.state.title, subtitle: [card.state.subtitle, card.spot.name].compactMap { $0 }.joined(separator: " "), run: card.id, keywords: card.spot.keywords)
    }

    func markFound(_ id: String) {
        guard !spotListIsStale else { return }
        let card = card(id: id).flatMap { $0.spot.isFound ? Self.foundItem($0) : nil }
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
