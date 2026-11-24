import OpenspotCore
import SwiftUI

struct ToastStackView: View {
    let toasts: Toasts

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(toasts.shown.enumerated()), id: \.element.id) { index, toast in
                let place = toasts.places[toast.id]
                ToastView(toast: toast, showsContent: place?.showsContent ?? true, width: toasts.width, toasts: toasts)
                    .scaleEffect(place?.scale ?? 1, anchor: .bottom)
                    .offset(y: place?.offset ?? 0)
                    .mask(alignment: .top) {
                        Rectangle()
                            .padding(.horizontal, -SpotTokens.toastRoom)
                            .padding(.bottom, -SpotTokens.toastMaxSize.height * CGFloat(Toasts.limit))
                            .offset(y: place?.edge ?? -SpotTokens.toastRoom)
                    }
                    .zIndex(-Double(index))
            }
        }
        .padding(SpotTokens.toastRoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { toasts.hold($0) }
        .id(SpotLoadedTheme.shared.layout)
    }
}
