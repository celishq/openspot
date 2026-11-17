import OpenspotCore
import SwiftUI

struct SpotThemeStage: View {
    let model: SpotThemeModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("Appearance", selection: Binding(get: { model.isDark }, set: { model.show(isDark: $0) })) {
                Text("Dark").tag(true)
                Text("Light").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .padding(SpotTokens.menuPadding)
            ScrollView([.vertical, .horizontal]) {
                SpotsView(model: model.stage)
                    .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
                    .environment(\.spotIsShown, model.stage.isShown)
                    .id(model.layout)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .defaultScrollAnchor(.top)
        }
    }
}
