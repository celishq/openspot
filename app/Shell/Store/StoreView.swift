import OpenspotCore
import SwiftUI

struct StoreView: PageView {
    let store: Store
    let model: SpotsModel?
    @State var isTrying = false
    @State var areFilesFolded = true
    @State var sample: StoreSample?
    @State private var shownAsk: StoreAsk?
    @State var drag = StoreDrag()

    var body: some View {
        PageWindow(
            title: store.title,
            page: shown,
            visit: store.visit,
            reveal: (store.page == nil ? PageTitle.heading : PageTitle.header).reveal,
            query: Binding(get: { store.query }, set: { store.search($0) }),
            back: store.back.isEmpty ? nil : { Task { await store.goBack() } },
            forward: store.forward.isEmpty ? nil : { Task { await store.goForward() } }
        ) {
            StoreSidebar(store: store, drag: drag)
        } content: {
            if let page = store.page {
                spotPage(page)
            } else {
                placePage
            }
        }
        .overlay { StoreCarriedCard(drag: drag, cards: store.cards) }
        .coordinateSpace(name: StoreDrag.space)
        .sheet(isPresented: Binding(get: { store.ask != nil }, set: { if !$0 { store.dismissAsk() } })) {
            if let ask = store.ask ?? shownAsk { StoreAskView(store: store, ask: ask) }
        }
        .onChange(of: store.ask) { _, ask in if let ask { shownAsk = ask } }
        .sheet(isPresented: $isTrying) { trySheet }
        .task(id: store.page?.id) { await loadSample() }
        .onChange(of: store.page?.id) {
            isTrying = false
            areFilesFolded = true
        }
    }

    private var shown: String {
        "\(store.title)/\(store.page?.id ?? "")/\(store.query)"
    }
}
