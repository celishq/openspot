import SwiftUI

/// The top of a page of Raycast extensions: the selected extension on the left, an arrow, and on the right what it becomes in
/// Openspot. That is the card of the spot that does its job, as the grid shows it, or an empty card for a spot that an agent
/// makes. Each side has its name and, under it, where it lives. A line under both says what the keys do on the selected row.
/// With no row selected, as on a button, it shows the first row.
struct SpotView: View {
    let spot: SpotInput

    private static let icon: CGFloat = 52
    private static let arrow: CGFloat = 44
    private static let lines: CGFloat = 36
    private static let hint: CGFloat = 24
    private static let arrowFont = Font.system(size: 20, weight: .semibold)
    private static let mark = Font.system(size: 22, weight: .medium)

    private var theme: SpotTheme { spot.theme }
    private var secondary: Color { theme.color.ink.opacity(theme.color.secondary) }

    var body: some View {
        let row = spot.rows.first { $0.id == spot.selection } ?? spot.rows.first
        let top = CGSize(width: spot.size.width, height: spot.size.height - Self.hint - theme.space.padding)
        VStack(spacing: theme.space.padding) {
            pair(row, size: top)
            Text(hint(for: row))
                .font(theme.font.detail)
                .foregroundStyle(secondary)
                .frame(maxWidth: .infinity, minHeight: Self.hint)
                .background(theme.color.ink.opacity(theme.color.fill), in: Capsule())
        }
        .frame(width: spot.size.width, height: spot.size.height)
    }

    private func hint(for row: SpotRow?) -> String {
        let id = row?.id ?? ""
        let name = row?["spot.title"] ?? ""
        if id.hasPrefix("use:") { return "⏎ Open \(name)  ·  ⌘I Learn More" }
        if id.hasPrefix("get:") { return "⏎ Tick or untick  ·  ⌘I Learn More" }
        return "⏎ Tick or untick"
    }

    private func pair(_ row: SpotRow?, size: CGSize) -> some View {
        let room = CGSize(width: (size.width - Self.arrow) / 2 - theme.space.padding, height: size.height - Self.lines - theme.space.padding)
        return HStack(spacing: 0) {
            side(row?["title"] ?? "", "Raycast") { from(row) }
            Image(systemName: "arrow.right")
                .font(Self.arrowFont)
                .foregroundStyle(secondary)
                .frame(width: Self.arrow, height: room.height)
                .frame(maxHeight: .infinity, alignment: .top)
            side(row?["spot.title"] ?? "Your own spot", place(of: row)) { to(row, room: room) }
        }
        .frame(width: size.width, height: size.height)
    }

    private func place(of row: SpotRow?) -> String {
        guard row?["spot"] != nil else { return "Made by your agent" }
        let detail = row?["detail"] ?? ""
        if detail.hasSuffix("in the Store") { return "In the Store" }
        if detail.hasSuffix("turned off") { return "Turned off" }
        return "In Openspot"
    }

    private func side(_ title: String, _ caption: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, theme.space.padding)
            Text(title)
                .font(theme.font.title)
                .foregroundStyle(theme.color.ink)
                .lineLimit(1)
            Text(caption)
                .font(theme.font.detail)
                .foregroundStyle(secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func from(_ row: SpotRow?) -> some View {
        let icon = row?["icon"] ?? "puzzlepiece.extension"
        Group {
            if icon.hasPrefix("/") {
                spot.media(icon).id(icon)
            } else {
                Image(systemName: icon).font(Self.mark).foregroundStyle(theme.color.ink)
            }
        }
        .frame(width: Self.icon, height: Self.icon)
    }

    @ViewBuilder
    private func to(_ row: SpotRow?, room: CGSize) -> some View {
        if let id = row?["spot"] {
            let size = spot.cardSize(id)
            let scale = size.width > 0 && size.height > 0 ? min(1, room.width / size.width, room.height / size.height) : 1
            spot.card(id)
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
                .scaleEffect(scale)
                .frame(width: size.width * scale, height: size.height * scale)
        } else {
            let side = min(room.width, room.height)
            Image(systemName: "sparkles")
                .font(Self.mark)
                .foregroundStyle(secondary)
                .frame(width: side, height: side)
                .overlay {
                    RoundedRectangle(cornerRadius: spot.corner, style: .continuous)
                        .strokeBorder(theme.color.ink.opacity(theme.color.track), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
        }
    }
}
