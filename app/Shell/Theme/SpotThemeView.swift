import OpenspotCore
import SwiftUI

struct SpotThemeView: View {
    let model: SpotThemeModel
    let done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                SpotThemeList(model: model)
                    .frame(width: SpotTokens.themeListWidth)
                Divider()
                SpotThemeRows(model: model)
                    .frame(width: SpotTokens.themeRowsWidth)
                Divider()
                SpotThemeStage(model: model)
            }
            Divider()
            SpotThemeFooter(hint: hint, done: done)
        }
        .environment(\.spotSurfaceEdge, .window)
        .background { Color.clear.spotGlass(in: ConcentricRectangle()).ignoresSafeArea() }
    }

    private var hint: String {
        if let fault = model.fault { return fault }
        if model.isBuiltIn { return "\(ThemeFolder.builtInName) is built in. Duplicate it to change a value." }
        return "A change saves to the theme when you let go. Sizes, type and motion reach the panel when it next hides."
    }
}
