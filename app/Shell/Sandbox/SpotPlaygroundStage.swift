import OpenspotCore
import SwiftUI

/// The right pane of the playground: the picker of the place on the window's own background, then the real panel of the
/// playground, with its field, its grid and its sheets, centred on a blur of the desktop.
struct SpotPlaygroundStage: View {
    @Bindable var model: SpotSandboxModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Place", selection: Binding(get: { model.place }, set: { model.choose($0) })) {
                    ForEach(PlaygroundPlace.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .padding(SpotTokens.padding)
            .background(SpotTheme.window)
            ScrollView([.vertical, .horizontal]) {
                SpotsView(model: model.panel.model)
                    .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
                    .environment(\.spotIsShown, model.panel.model.isShown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .defaultScrollAnchor(.center)
            .background(SpotBlur(radius: SpotTheme.blur))
        }
    }
}
