import SwiftUI

/// The round button of a sheet, with one symbol, such as close or swap.
struct SpotRoundButton: View {
    private static let fillOpacity = 0.2

    let symbol: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
                .background(Color.white.opacity(Self.fillOpacity), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
