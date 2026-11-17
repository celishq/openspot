import AppKit
import OpenspotCore
import SwiftUI

struct SpotThemeFooter: View {
    let hint: String

    var body: some View {
        HStack(spacing: SpotTokens.padding) {
            Text(hint)
                .font(SpotType.detail)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Button {
                NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil)
            } label: {
                Text("Done")
                    .font(SpotType.body)
                    .padding(.horizontal, SpotTokens.padding)
                    .frame(height: SpotTokens.menuRowHeight)
                    .spotFill(isActive: true, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SpotTokens.padding)
        .padding(.vertical, SpotTokens.menuPadding)
    }
}
