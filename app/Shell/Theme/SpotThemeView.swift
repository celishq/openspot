import OpenspotCore
import SwiftUI

struct SpotThemeView: View {
    let model: SpotThemeModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: SpotTokens.themeGap) {
                SpotThemeList(model: model)
                    .frame(width: SpotTokens.themeListWidth)
                SpotThemeRows(model: model)
                SpotThemeStage(model: model)
                    .frame(width: SpotTokens.themeStageWidth)
            }
            .padding([.leading, .trailing, .top], SpotTokens.themePadding)
            SpotThemeFooter(model: model, hint: hint)
        }
        .ignoresSafeArea(edges: [.horizontal, .bottom])
        .overlayPreferenceValue(SpotThemeTipAnchor.self, alignment: .topLeading) { anchor in
            GeometryReader { proxy in
                if let anchor, let tip = model.tip {
                    let rect = proxy[anchor]
                    SpotTipPill(text: tip)
                        .position(x: rect.midX, y: rect.maxY + SpotTokens.placeGap + SpotTokens.hintPillHeight / 2)
                }
            }
            .allowsHitTesting(false)
        }
        .modifier(SpotWindowSurface())
    }

    private var hint: String {
        if let fault = model.fault { return fault }
        if model.isBuiltIn { return "\(ThemeFolder.builtInName) is built in. Duplicate it to change a value." }
        return "A change saves to the theme when you let go. While this window is open, the panel draws the theme you edit."
    }
}
