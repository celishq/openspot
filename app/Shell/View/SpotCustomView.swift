import OpenspotCore
import SwiftUI

/// A plugin's own view, which fills its whole card and is clipped to the card's shape. It gets the head of the last read
/// and the card's size, inset, corner and theme, and it draws only: a press goes to the card (V3, V5). While it builds
/// the card stays empty, and a view that fails shows why, shrunk to fit.
struct SpotCustomView: View {
    let source: String
    let values: [String: [String]]
    let card: SpotSize
    let views: SpotViews
    @Environment(\.spotIsShown) private var isShown

    private var size: CGSize {
        CGSize(width: SpotTokens.width(columns: card.columns), height: SpotTokens.height(rows: card.rows))
    }

    private var corner: CGFloat {
        SpotTokens.corner(for: card)
    }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .allowsHitTesting(false)
            .task(id: "\(source)\n\(isShown)") { await views.load(source) }
    }

    /// What the view reads of its card, by the keys of `SpotInput`.
    private var room: [String: Any] {
        [
            "size": size,
            "inset": SpotTokens.padding,
            "corner": corner,
            "ink": SpotTheme.ink,
            "secondary": SpotTheme.secondaryLight,
            "accent": SpotTheme.accent,
            "title": SpotType.title,
            "detail": SpotType.detail,
            "metric": SpotType.metric,
            "value": SpotType.value
        ]
    }

    @ViewBuilder
    private var content: some View {
        switch views.phase(of: source) {
        case .building:
            Color.clear
        case .ready(let make):
            make(values, room, { _ in })
        case .failed(let reason):
            Text(reason)
                .font(SpotType.detail)
                .minimumScaleFactor(0.5)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                .padding(SpotTokens.padding)
        }
    }
}
