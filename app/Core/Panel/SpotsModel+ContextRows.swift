import Foundation

extension SpotsModel {
    func showContext() -> [Entry] {
        guard let chip = context.selectedChip, let source = entry(chip.source) else { return [] }
        guard let value = chip.value else {
            return [Entry(spot: source.spot, item: SpotItem(title: chip.words.title, run: "", picture: Icon(text: chip.symbol)), role: .preview, detail: "")]
        }
        let shown = ContextPreview(value)
        let preview = Entry(spot: source.spot, item: SpotItem(title: shown.text, run: "", picture: shown.picture), role: .preview, detail: shown.caption)
        let text = query.trimmingCharacters(in: .whitespaces)
        let found = commands.takers(of: value, matching: text.isEmpty ? nil : runs.search(of: text), limit: Self.contextRows)
        let taken = found.compactMap { row in
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.title, run: ""), role: .taker, detail: Self.takes(value.kind)) }
        }
        return [preview] + taken
    }

    static let contextRows = 5

    private static func takes(_ kind: ContextValue.Kind) -> String {
        switch kind {
        case .file: "Takes the files"
        case .url: "Takes the link"
        case .text: "Takes the text"
        }
    }
}
