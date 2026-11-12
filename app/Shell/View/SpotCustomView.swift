import OpenspotCore
import SwiftUI

/// A spot's own view, which fills its area of a card or a sheet drawing, or else its whole card, and is clipped to that
/// shape. It gets the block of its `view` component and its size, inset, corner and theme, and it draws only (protocol:
/// Views). A card or a sheet loads it. A view that fails shows why, shrunk to fit.
/// The view exists only while the panel shows, so a hidden panel runs none of its work.
struct SpotCustomView: View {
    let source: String
    let values: [String: [String]]
    let card: SpotSize
    /// The size of its area in a card drawing. Nil fills the whole card.
    var room: CGSize?
    let views: SpotViews
    @Environment(\.spotIsShown) private var isShown

    private var size: CGSize {
        room ?? CGSize(width: SpotTokens.width(columns: card.columns), height: SpotTokens.height(rows: card.rows))
    }

    private var corner: CGFloat {
        room == nil ? SpotTokens.corner(for: card) : SpotTokens.radius - SpotTokens.padding
    }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
            .allowsHitTesting(false)
    }

    /// What the view reads of its card, by the keys of `SpotInput`.
    private var input: [String: Any] {
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
            EmptyView()
        case .ready(let make) where isShown:
            make(values, input, { _ in })
        case .ready:
            EmptyView()
        case .failed(let reason):
            Text(reason)
                .font(SpotType.detail)
                .minimumScaleFactor(0.5)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                .padding(SpotTokens.padding)
        }
    }
}
