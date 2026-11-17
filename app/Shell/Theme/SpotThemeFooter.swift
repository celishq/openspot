import OpenspotCore
import SwiftUI

struct SpotThemeFooter: View {
    let hint: String
    let done: () -> Void

    var body: some View {
        HStack(spacing: SpotTokens.padding) {
            Text(hint)
                .font(SpotType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Button {
                done()
            } label: {
                Text("Done")
                    .font(SpotType.body)
                    .padding(.horizontal, SpotTokens.padding)
                    .frame(height: SpotTokens.menuRowHeight)
                    .spotFill(isActive: true, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, SpotTokens.padding)
        .padding(.vertical, SpotTokens.menuPadding)
    }
}
