import OpenspotCore
import SwiftUI

struct SettingsExplainer: View {
    let title: String
    let line: String
    let facts: [SettingsFact]
    var states: [SpotReadiness] = []
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.settingsSheetGap) {
            VStack(alignment: .leading, spacing: SpotTokens.settingsTitleGap) {
                Text(title)
                    .font(SpotType.settingsTitle)
                Text(line)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: SpotTokens.settingsRowGap) {
                ForEach(facts, id: \.self) { fact in
                    line(Image(systemName: fact.symbol).foregroundStyle(fact.isWarning ? SpotTheme.settingsLate : .secondary), Text(fact.text))
                }
            }
            if !states.isEmpty {
                VStack(alignment: .leading, spacing: SpotTokens.settingsRowGap) {
                    ForEach(states, id: \.self) { state in
                        line(
                            Circle().fill(SpotTheme.settingsState(state)).frame(width: SpotTokens.settingsDot, height: SpotTokens.settingsDot),
                            Text("\(Text(state.word).fontWeight(.medium))  \(Text(state.line).foregroundStyle(.secondary))")
                        )
                    }
                }
            }
            HStack {
                Spacer()
                Button("Done", action: done)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, SpotTokens.settingsSheetTop)
        }
    }

    private func line(_ mark: some View, _ words: Text) -> some View {
        HStack(spacing: SpotTokens.settingsRowGap) {
            mark.frame(width: SpotTokens.settingsRowTile)
            words
        }
    }
}
