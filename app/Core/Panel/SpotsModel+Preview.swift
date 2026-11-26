import Foundation

extension SpotsModel {
    static let ownPreviewLimit = 50
    static let previewLimit: TimeInterval = 3

    var previewRow: KeyRow {
        KeyRow(" ", glyph: "Space", words: previewWords) { [self] _ in
            guard searchText.isEmpty, isPreviewing || previewedItem != nil else { return nil }
            isPreviewing.toggle()
            takePreview()
            return true
        }
    }

    var previewEscapeRow: KeyRow {
        KeyRow("escape") { [self] _ in
            guard isPreviewing else { return nil }
            closePreview()
            return true
        }
    }

    private var previewWords: String? {
        guard previewedItem != nil else { return nil }
        return isPreviewing ? "Close Preview" : "Preview"
    }

    private var previewedItem: SpotItem? {
        guard openSheetID != nil, let item = target?.item, ItemPreview.holds(item) || previewSpot(of: item) != nil else { return nil }
        return item
    }

    func rowType(of item: SpotItem) -> (spot: Spot, type: Manifest.RowType)? {
        guard let value = item.fields.first(where: { ($0.key == "text" || $0.key == "url") && !$0.value.isEmpty })?.value else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for spot in sheets.values.map(\.spot).filter({ !$0.types.isEmpty }).sorted(by: { $0.id < $1.id }) {
            if let type = spot.types.first(where: { $0.holds(text) }) { return (spot, type) }
        }
        return nil
    }

    private func previewSpot(of item: SpotItem) -> (spot: Spot, type: String?)? {
        if let spot = openSheet?.spot, spot.triggers.previews { return (spot, nil) }
        guard let typed = rowType(of: item), typed.spot.triggers.previews else { return nil }
        return (typed.spot, typed.type.name)
    }

    func typedActions(on item: SpotItem) -> [OfferedAction] {
        guard let typed = rowType(of: item) else { return [] }
        return typed.spot.actions.filter { $0.type == typed.type.name }.compactMap { action in
            guard let title = action.title else { return nil }
            let command = CommandAction(id: action.id, title: title, key: nil, scope: .spot, after: action.closes ? .close : .stay, confirm: action.confirm)
            return OfferedAction(action: command, owner: typed.spot.id, group: typed.spot.name)
        }
    }

    func closePreview() {
        guard isPreviewing else { return }
        isPreviewing = false
        takePreview()
    }

    func takePreview() {
        if openSheetID == nil { isPreviewing = false }
        let item = isPreviewing ? previewedItem : nil
        let next = item.flatMap { ownPreviews[$0.run] ?? ItemPreview(item: $0) }
        if next != preview { preview = next }
        let place = next == nil ? nil : openSheet?.sheetRect
        if place != previewPlace {
            previewPlace = place
            if let place { host.showPreview(beside: place) } else { host.hidePreview() }
        }
        if let item, ownPreviews[item.run] == nil, let asked = previewSpot(of: item) { askPreview(of: item, in: asked.spot, type: asked.type) }
    }

    private func askPreview(of item: SpotItem, in spot: Spot, type: String?) {
        previewAsk?.cancel()
        let typed: [TextBlock.Field] = type.map { [.init(key: "input.type", value: $0)] } ?? []
        let input = TextBlock(fields: [.init(key: "input.item", value: item.run)] + item.carried.map { .init(key: "input.\($0.key)", value: $0.value) } + typed).text
        previewAsk = Task { [weak self, runs] in
            guard let text = try? await runs.answer(of: spot, EventName.itemPreview, input: input, limit: Self.previewLimit), !Task.isCancelled, let self else { return }
            guard let own = ItemPreview.own(text, of: item.run) else { return }
            if ownPreviews.count >= Self.ownPreviewLimit { ownPreviews.removeAll() }
            ownPreviews[item.run] = own
            asOnePress { takePreview() }
        }
    }
}
