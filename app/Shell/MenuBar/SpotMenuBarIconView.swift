import OpenspotCore
import SwiftUI

/// The icon of the Openspot item, or for a moment the symbol of the command whose key a person pressed, or of the toast
/// that shows. The leaving icon shrinks and fades as the next one grows in. While work runs, the icon is cut out of a pill
/// of the menu bar's colour.
struct SpotMenuBarIconView: View {
    let model: SpotsModel
    let image: NSImage
    let toast: Toast?
    var isWorking = false

    /// The width of the item, which holds the pill and stays the same with no work, so that no item beside it moves.
    static let width: CGFloat = 30

    private static let small = 0.5
    private static let pillInset: CGFloat = 2
    private static let workScale = 0.72
    private static let leave = SpotMotion.fade(isShown: false)
    private static let arrive = SpotMotion.press

    var body: some View {
        ZStack {
            swap.scaleEffect(isWorking ? Self.workScale : 1).opacity(isWorking ? MotionTokens.hiddenOpacity : 1)
            ZStack {
                Capsule().padding(.vertical, Self.pillInset)
                swap.scaleEffect(isWorking ? Self.workScale : 1).blendMode(.destinationOut)
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
