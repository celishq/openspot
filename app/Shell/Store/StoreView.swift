import OpenspotCore
import SwiftUI

struct StoreView: View {
    let store: Store
    let model: SpotsModel?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                StoreSidebar(store: store)
                    .frame(width: SpotTokens.storeSidebarWidth)
                Divider()
                Group {
                    if let page = store.page {
                        StorePageView(store: store, page: page, model: model)
                    } else {
                        StoreShelfView(store: store)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            Divider()
            SpotWindowFooter(hint: "Drag a spot to My spots to install it", tip: "Close the Store") {}
        }
        .overlay {
            if let ask = store.ask { StoreAskView(store: store, ask: ask) }
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .modifier(SpotWindowSurface())
    }
}
