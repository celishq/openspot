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
        guard openSheetID != nil, let item = target?.item, ItemPreview.holds(item) || openSheet?.spot.triggers.previews == true else { return nil }
        return item
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
        if let item, let spot = openSheet?.spot, spot.triggers.previews, ownPreviews[item.run] == nil { askPreview(of: item, in: spot) }
    }

    private func askPreview(of item: SpotItem, in spot: Spot) {
        previewAsk?.cancel()
        let input = TextBlock(fields: [.init(key: "input.item", value: item.run)] + item.carried.map { .init(key: "input.\($0.key)", value: $0.value) }).text
        previewAsk = Task { [weak self, runs] in
            guard let text = try? await runs.answer(of: spot, EventName.itemPreview, input: input, limit: Self.previewLimit), !Task.isCancelled, let self else { return }
            guard let own = ItemPreview.own(text, of: item.run) else { return }
            if ownPreviews.count >= Self.ownPreviewLimit { ownPreviews.removeAll() }
            ownPreviews[item.run] = own
            asOnePress { takePreview() }
        }
    }
}
