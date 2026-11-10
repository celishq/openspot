import SwiftUI

/// A thin bar at the leading edge of a text or a number, in the colour that a script gives it, such as a calendar's.
struct SpotColorBar: ViewModifier {
    private static let width: CGFloat = 4
    private static let gap: CGFloat = 8

    let color: String?

    func body(content: Content) -> some View {
        if let color {
            HStack(spacing: Self.gap) {
                RoundedRectangle(cornerRadius: Self.width / 2, style: .continuous)
                    .fill(Self.color(color))
                    .frame(width: Self.width)
                content
            }
        } else {
            content
        }
    }

    /// The colour of a `#RRGGBB` text.
    static func color(_ text: String) -> Color {
        let value = Int(text.dropFirst(), radix: 16) ?? 0
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
