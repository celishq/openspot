import OpenspotCore
import SwiftUI

struct SpotMenuBarIconView: View {
    let model: SpotsModel
    let image: NSImage
    let toast: Toast?
    var isWorking = false

    private static var leave: Animation { SpotMotion.fade(isShown: false) }
    private static var arrive: Animation { SpotMotion.press }

    var body: some View {
        ZStack {
            swap.scaleEffect(isWorking ? MotionTokens.menuBarWorkScale : 1).opacity(isWorking ? MotionTokens.hiddenOpacity : 1)
            ZStack {
                Capsule().padding(.vertical, SpotTokens.menuBarPillInset)
                swap.scaleEffect(isWorking ? MotionTokens.menuBarWorkScale : 1).blendMode(.destinationOut)
            }
            .compositingGroup()
            .opacity(isWorking ? 1 : MotionTokens.hiddenOpacity)
        }
        .animation(SpotMotion.fade(isShown: isWorking), value: isWorking)
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var swap: some View {
        ZStack {
            icon
                .id(symbol)
                .transition(.asymmetric(
                    insertion: .scale(scale: MotionTokens.menuBarSwapScale).combined(with: .opacity).animation(Self.arrive),
                    removal: .scale(scale: MotionTokens.menuBarSwapScale).combined(with: .opacity).animation(Self.leave)
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
