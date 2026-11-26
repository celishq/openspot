import OpenspotCore
import SwiftUI

struct StoreView: PageView {
    let store: Store
    let model: SpotsModel?
    @State var isTrying = false

    var body: some View {
        PageWindow(
            title: store.title,
            page: shown,
            reveal: (store.page == nil ? PageTitle.heading : PageTitle.header).reveal,
            query: Binding(get: { store.query }, set: { store.search($0) }),
            back: store.back.isEmpty ? nil : { Task { await store.goBack() } },
            forward: store.forward.isEmpty ? nil : { Task { await store.goForward() } }
        ) {
            StoreSidebar(store: store)
        } content: {
            if let page = store.page {
                spotPage(page)
            } else {
                placePage
            }
        }
        .sheet(isPresented: Binding(get: { store.ask != nil }, set: { if !$0 { store.dismissAsk() } })) {
            if let ask = store.ask { StoreAskView(store: store, ask: ask) }
        }
        .sheet(isPresented: $isTrying) { trySheet }
        .onChange(of: store.page?.id) { isTrying = false }
    }

    private var shown: String {
        "\(store.title)/\(store.page?.id ?? "")/\(store.query)"
    }
}
