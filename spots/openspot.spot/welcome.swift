import SwiftUI

/// One piece of a Welcome page: a hand-drawn note of the heading, when the block names a `drawing`, or one thing to try,
/// drawn like a spot's card. A drawing shows only its shape, in the accent colour, as tall as its block.
struct SpotView: View {
    let spot: SpotInput

    private static let cardNote = CGSize(width: 10, height: 13)
    private static let cardNoteOffset = CGSize(width: 30, height: 5)
    private static let glyph = Font.system(size: 17, weight: .semibold)

    private var theme: SpotTheme { spot.theme }
    private var secondary: Color { theme.color.ink.opacity(theme.color.secondary) }

    var body: some View {
        Group {
            if let drawing = spot["drawing"] {
                Drawing(path: drawing, color: theme.color.accent)
            } else {
                card
            }
        }
        .frame(width: spot.size.width, height: spot.size.height, alignment: .topLeading)
    }

    private var card: some View {
        HStack(spacing: theme.space.padding - 5) {
            Image(systemName: spot["icon"] ?? "square.dashed")
                .font(Self.glyph)
                .foregroundStyle(theme.color.ink)
                .frame(width: theme.space.glyph, height: theme.space.glyph)
                .background(theme.color.ink.opacity(theme.color.track), in: Circle())
                .overlay(alignment: .topLeading) {
                    if let note = spot["note"] {
                        Drawing(path: note, color: theme.color.accent)
                            .frame(width: Self.cardNote.width, height: Self.cardNote.height)
                            .offset(Self.cardNoteOffset)
                    }
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(spot["title"] ?? "").font(theme.font.title).foregroundStyle(theme.color.ink).lineLimit(1)
                if let detail = spot["detail"] {
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
