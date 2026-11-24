import OpenspotCore
import SwiftUI

struct ToastStackView: View {
    let toasts: Toasts

    var body: some View {
        ZStack(alignment: .top) {
            ForEach(Array(toasts.shown.enumerated()), id: \.element.id) { index, toast in
                let place = toasts.places[toast.id]
                ToastView(toast: toast, showsContent: place?.showsContent ?? true, width: toasts.width)
                    .mask(alignment: .top) { Rectangle().padding([.horizontal, .bottom], -SpotTokens.toastRoom).offset(y: place?.cut ?? 0) }
                    .scaleEffect(place?.scale ?? 1, anchor: .bottom)
                    .offset(y: place?.offset ?? 0)
                    .zIndex(-Double(index))
            }
        }
        .padding(SpotTokens.toastRoom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .onHover { toasts.hover($0) }
        .id(SpotLoadedTheme.shared.layout)
    }
}
