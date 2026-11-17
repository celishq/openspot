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
            .controlSize(.small)
            .frame(height: SpotTokens.themeLine)
            ScrollView(.vertical) {
                let scale = SpotTokens.stageScale
                SpotsView(model: model.stage)
                    .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight)
                    .environment(\.spotIsShown, model.stage.isShown)
                    .disabled(true)
                    .allowsHitTesting(false)
                    .id(model.layout)
                    .overlay(alignment: .topLeading) {
                        ZStack(alignment: .topLeading) {
                            Color.clear.contentShape(Rectangle())
                            SpotThemeMarkLayer(model: model)
                        }
                    }
                    .onContinuousHover { phase in
                        if case .active(let point) = phase { model.point(at: point) } else { model.point(at: nil) }
                    }
                    .scaleEffect(scale, anchor: .topLeading)
                    .frame(width: SpotTokens.panelWidth * scale, height: SpotTokens.panelHeight * scale, alignment: .topLeading)
                    .frame(maxWidth: .infinity)
            }
            .defaultScrollAnchor(.top)
        }
    }
}
