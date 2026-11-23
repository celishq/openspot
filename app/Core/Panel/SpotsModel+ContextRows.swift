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
            entry(row.spot).map { Entry(spot: $0.spot, item: SpotItem(title: row.title, run: ""), role: .taker, detail: Self.takes(value.kind)) }
        }
        return taken
    }

    func hold(_ preview: ContextPreview?) {
        guard preview != contextPreview else { return }
        change(isShown ? holdMotion : nil) {
            contextPreview = preview
            if fieldHoldsValue != (preview != nil) { fieldHoldsValue = preview != nil }
        }
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
