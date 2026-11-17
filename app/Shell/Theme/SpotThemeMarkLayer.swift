import OpenspotCore
import SwiftUI

struct SpotThemeMarkLayer: View {
    let model: SpotThemeModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let mark = model.lit {
                if case .band = mark.shape {
                    SpotThemeMarkShape(mark: mark).fill(SpotTheme.accent.opacity(SpotTheme.markFill))
                    SpotThemeMarkShape(mark: mark).stroke(SpotTheme.accent, lineWidth: SpotTokens.thinRing)
                } else {
                    SpotThemeMarkShape(mark: mark).stroke(SpotTheme.accent, style: StrokeStyle(lineWidth: SpotTokens.themeMarkLine, lineCap: .round))
                }
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: mark.hit.width, height: mark.hit.height)
                    .anchorPreference(key: SpotThemeTipAnchor.self, value: .bounds) { $0 }
                    .offset(x: mark.hit.minX, y: mark.hit.minY)
                    .gesture(
                        DragGesture(minimumDistance: 1, coordinateSpace: .global)
                            .onChanged { model.drag(by: $0.translation) }
                            .onEnded { _ in model.drop() }
                    )
            }
        }
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topLeading)
        .allowsHitTesting(model.lit != nil)
    }
}
