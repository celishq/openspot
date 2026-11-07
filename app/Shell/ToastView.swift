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
        }
        .padding(.horizontal, ToastPanel.margin)
        .padding(.vertical, 10)
        .modifier(SpotGlass(radius: SpotTokens.rowHeight / 3))
        .padding(ToastPanel.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.spotIsShown, toast.isShown)
    }
}
