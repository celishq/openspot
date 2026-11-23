import OpenspotCore
import SwiftUI

struct SpotMenuBarIconView: View {
    let model: SpotsModel
    let image: NSImage
    let toast: Toast?

    static let width: CGFloat = 30

    private static let small = 0.5
    private static let leave = SpotMotion.fade(isShown: false)
    private static let arrive = SpotMotion.press

    var body: some View {
        swap
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var swap: some View {
        ZStack {
            icon
                .id(symbol)
                .transition(.asymmetric(
                    insertion: .scale(scale: Self.small).combined(with: .opacity).animation(Self.arrive),
                    removal: .scale(scale: Self.small).combined(with: .opacity).animation(Self.leave)
                ))
        }
    }

    private var symbol: String? {
        model.menuBarSymbol(during: toast.flatMap { $0.isShown ? $0.kind : nil })
    }

    @ViewBuilder
    private var icon: some View {
        if let symbol {
            Image(systemName: symbol).font(SpotType.menuBar)
        } else {
            Image(nsImage: image).renderingMode(.template)
        }
    }
}
