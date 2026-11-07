import OpenspotCore
import SwiftUI

/// A short message from Openspot on the same surface as a spot.
struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            if let symbol = toast.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SpotTheme.ink)
            }
            Text(toast.message)
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            if let key = toast.key {
                SpotKeyLabel(text: key.text, isRecording: false)
            }
        }
        .padding(.horizontal, ToastPanel.margin)
        .padding(.vertical, 10)
        .modifier(SpotGlass(radius: SpotTokens.rowHeight / 3))
        .contentShape(Rectangle())
        .onTapGesture { toast.open?() }
        .padding(ToastPanel.margin)
        .environment(\.spotIsShown, toast.isShown)
    }
}
