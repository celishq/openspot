import AppKit
import OpenspotCore
import SwiftUI

@MainActor
enum StoreWindow {
    private static var kept: (store: Store, window: SpotSheetWindow)?

    static func show(model: SpotsModel, id: String?, search: String?) async -> Bool {
        await show(model: model) { await $0.show(id, search: search) }
    }

    static func show(model: SpotsModel, file: URL) async -> Bool {
        await show(model: model) { await $0.show(file: file) }
    }

    private static func show(model: SpotsModel, _ open: (Store) async -> Bool) async -> Bool {
        let (store, window) = kept ?? make(model: model)
        kept = (store, window)
        guard await open(store) else { return false }
        if model.isShown { model.host.dismiss() }
        window.show()
        return true
    }

    private static func make(model: SpotsModel) -> (Store, SpotSheetWindow) {
        let store = Store(places: model.files, changed: { await model.spotsChanged() }, toast: { model.toast($0) })
        let window = SpotSheetWindow.make(title: "Store", name: "store-window", content: StoreView(store: store, model: model))
        window.takesEscape = {
            if store.ask != nil {
                store.dismissAsk()
            } else if store.page != nil {
                store.closePage()
            } else {
                return false
            }
            return true
        }
        return (store, window)
    }
}
