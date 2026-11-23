import OpenspotCore
import SwiftUI

struct SpotColorBar: ViewModifier {
    let color: String?

    func body(content: Content) -> some View {
        if let color {
            HStack(spacing: SpotTokens.colorBarGap) {
                RoundedRectangle(cornerRadius: SpotTokens.colorBarWidth / 2, style: .continuous)
                    .fill(Self.color(color))
                    .frame(width: SpotTokens.colorBarWidth)
                content
            }
        } else {
            content
        }
    }

    static func color(_ text: String) -> Color {
        let value = Int(text.dropFirst(), radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
