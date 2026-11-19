import OpenspotCore
import SwiftUI

struct OpenspotItemView: View {
    let model: SpotsModel
    let image: NSImage
    let toast: Toast?

    private static var leave: Animation { SpotMotion.fade(isShown: false) }
    private static var arrive: Animation { SpotMotion.press }

    var body: some View {
        ZStack {
            swap.opacity(isRunning ? MotionTokens.hiddenOpacity : 1)
            ZStack {
                Capsule().frame(height: SpotTokens.menuBarPill.height)
                swap.blendMode(.destinationOut)
            }
            .compositingGroup()
            .opacity(isRunning ? 1 : MotionTokens.hiddenOpacity)
        }
        .animation(SpotMotion.fade(isShown: isRunning), value: isRunning)
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

    private var isRunning: Bool {
        model.runningSummary != nil
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
