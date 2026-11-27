import OpenspotCore
import SwiftUI

struct SpotArrangeView: View {
    static let space = "arrange"

    let model: SpotsModel
    let size: CGSize
    let panelOrigin: CGPoint
    var drawsCover = true

    var body: some View {
        ZStack(alignment: .topLeading) {
            if drawsCover {
                SpotBackdropBlur(radius: SpotTokens.backdrop.blur)
                    .allowsHitTesting(false)
            }
            SpotTheme.arrangeCover
                .contentShape(Rectangle())
            if let layout = model.shelf.layout {
                SpotShelf(model: model, layout: layout)
                    .frame(width: size.width, height: layout.band.upperBound - layout.band.lowerBound)
                    .offset(y: layout.band.lowerBound)
            }
            if let panel = model.shelf.layout?.panel {
                SpotArrangeBar(model: model)
                    .frame(width: panel.width, height: SpotTokens.arrangeBar)
                    .offset(x: panel.minX)
            }
            SpotStoreButton(model: model)
                .frame(width: size.width, height: SpotTokens.arrangeFoot)
                .offset(y: size.height - SpotTokens.arrangeFoot)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .coordinateSpace(name: Self.space)
    }
}

private struct SpotStoreButton: View {
    let model: SpotsModel

    var body: some View {
        Button {
            Task { @MainActor in _ = await StoreWindow.show(model: model, id: nil, search: nil) }
        } label: {
            Label("Open the Store", systemImage: "bag")
                .font(SpotType.strong)
                .foregroundStyle(SpotTheme.ink)
                .padding(.horizontal, SpotTokens.arrangeButtonPadding)
                .frame(height: SpotTokens.arrangeButton)
                .background(SpotTheme.window, in: Capsule())
                .shadow(color: SpotTheme.liftShadowColor.opacity(SpotTheme.liftShadowStrength), radius: SpotTheme.shelfShadow, y: SpotTheme.shelfShadowDrop)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
