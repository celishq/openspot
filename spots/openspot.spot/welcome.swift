import SwiftUI

/// The top of a Welcome page: its words in large type, a drawing between them or a note under them, then the cards of
/// things to try. Each drawing shows only its shape, in the accent colour. The place keeps the height of its grid lines,
/// so the content sits at its top, at most `lead` below it.
struct SpotView: View {
    let spot: SpotInput

    private static let lead: CGFloat = 12
    private static let side: CGFloat = 6
    private static let titleSize: CGFloat = 24
    private static let detailSize: CGFloat = 15
    private static let gap: CGFloat = 6
    private static let picture: CGFloat = 38
    private static let pictureGap: CGFloat = 12
    private static let note: CGFloat = 41
    private static let noteGap: CGFloat = 4
    private static let cardNote = CGSize(width: 10, height: 13)
    private static let cardNoteOffset = CGSize(width: 30, height: 5)
    private static let glyph = Font.system(size: 17, weight: .semibold)

    private var theme: SpotTheme { spot.theme }
    private var secondary: Color { theme.color.ink.opacity(theme.color.secondary) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(maxHeight: Self.lead).layoutPriority(1)
            heading.padding(.horizontal, Self.side)
            let titles = spot.all("card.title")
            ForEach(titles.indices, id: \.self) { index in
                card(index).padding(.top, index == 0 ? Self.noteGap : Self.gap)
            }
            Spacer(minLength: 0)
        }
        .frame(width: spot.size.width, height: spot.size.height, alignment: .topLeading)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title = spot["title"] {
                Text(title).font(.system(size: Self.titleSize, weight: .bold)).foregroundStyle(theme.color.ink)
            }
            if let icon = spot["icon"] {
                Drawing(path: icon, color: theme.color.accent)
                    .frame(height: Self.picture)
                    .padding(.vertical, Self.pictureGap)
            }
            if let detail = spot["detail"] {
                Text(detail).font(.system(size: Self.detailSize)).foregroundStyle(secondary)
                    .padding(.top, spot["icon"] == nil ? Self.gap : 0)
            }
            if let note = spot["note"] {
                Drawing(path: note, color: theme.color.accent)
                    .frame(height: Self.note)
                    .padding(.top, Self.noteGap)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func card(_ index: Int) -> some View {
        let value = { (key: String) in spot.all(key).indices.contains(index) ? spot.all(key)[index] : nil }
        return HStack(spacing: theme.space.padding - 5) {
            Image(systemName: value("card.icon") ?? "square.dashed")
                .font(Self.glyph)
                .foregroundStyle(theme.color.ink)
                .frame(width: theme.space.glyph, height: theme.space.glyph)
                .background(theme.color.ink.opacity(theme.color.track), in: Circle())
                .overlay(alignment: .topLeading) {
                    if let note = value("card.note") {
                        Drawing(path: note, color: theme.color.accent)
                            .frame(width: Self.cardNote.width, height: Self.cardNote.height)
                            .offset(Self.cardNoteOffset)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(value("card.title") ?? "").font(theme.font.title).foregroundStyle(theme.color.ink).lineLimit(1)
                if let detail = value("card.detail") {
                    Text(detail).font(theme.font.detail).foregroundStyle(secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(theme.space.padding)
        .frame(maxWidth: .infinity)
        .frame(height: theme.space.cell)
        .background(theme.color.ink.opacity(theme.color.fill), in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous))
    }
}

/// A picture file that shows only its shape, in one colour, at its own proportions and no taller than its place.
private struct Drawing: View {
    let path: String
    let color: Color
    @State private var image: NSImage?

    private static let kept = NSCache<NSString, NSImage>()

    var body: some View {
        Group {
            if let shown = image ?? Self.kept.object(forKey: path as NSString) {
                Image(nsImage: shown)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
            } else {
                Color.clear
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .task(id: path) {
            guard Self.kept.object(forKey: path as NSString) == nil else { return }
            let path = path
            guard let loaded = await Task.detached(priority: .userInitiated, operation: { NSImage(contentsOfFile: path) }).value else { return }
            Self.kept.setObject(loaded, forKey: path as NSString)
            image = loaded
        }
    }
}
