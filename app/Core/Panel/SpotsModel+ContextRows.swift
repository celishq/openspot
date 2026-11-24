import Foundation

extension SpotsModel {
    func showContext() -> [Entry] {
        guard let chip = context.selectedChip, entry(chip.source) != nil else {
            hold(nil)
            return []
        }
        guard let value = chip.value else {
            hold(.loading)
            return []
        }
        hold(ContextPreview(value))
        let text = query.trimmingCharacters(in: .whitespaces)
        let found = commands.takers(of: value, matching: text.isEmpty ? nil : runs.search(of: text), limit: Self.contextRows)
        let taken = found.compactMap { row in
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.title, run: ""), role: .taker, detail: value.kind.takerWords) }
        }
        return taken
    }

    func hold(_ preview: ContextPreview?) {
        guard preview != fieldValue.preview else { return }
        change(isShown ? holdMotion : nil) { fieldValue = FieldValue(preview) }
    }

    static let contextRows = 5
}
