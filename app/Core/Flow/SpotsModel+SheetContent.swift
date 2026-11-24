import Foundation

extension SpotsModel {
    public func sheetContent(of entry: Entry) -> SheetContent {
        let id = entry.id
        let form = self.form?.entry.id == id ? self.form?.draft : nil
        return SheetContent(
            panel: shownParts(of: id),
            list: sheets[id]?.list ?? ItemList(),
            state: sheets[id]?.sheetState ?? entry.shownState,
            top: sheets[id]?.top ?? .plain,
            form: form,
            recording: recording,
            keys: keys,
            selection: { [weak self] in
                guard let sheet = self?.sheets[id] else { return 0 }
                return sheet.selectedPart == nil ? sheet.selection : Int.max
            },
            selectedPart: { [weak self] in self?.sheets[id]?.selectedPart?.id },
            nudge: { [weak self] in self?.sheets[id]?.nudge ?? .rest },
            menuOpening: { [weak self] in self?.sheets[id]?.menuOpening },
            act: { [weak self] in self?.act(of: $0) },
            create: { [weak self] in self?.createAction }
        )
    }
}
