import OpenspotCore
import SwiftUI

struct SpotCustomView: View, @MainActor Equatable {
    let source: String
    let values: [String: [String]]
    let card: SpotSize
    var room: CGSize?
    let views: SpotViews
    var send: ((String) -> Void)?
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotCards) private var cards

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source == rhs.source && lhs.values == rhs.values && lhs.card == rhs.card && lhs.room == rhs.room && lhs.views === rhs.views
            && (lhs.send == nil) == (rhs.send == nil)
    }

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
            .allowsHitTesting(send != nil)
    }

    private var cardView: (String) -> AnyView {
        let cards = cards
        return { id in
            var view = AnyView(EmptyView())
            MainActor.assumeIsolated { view = cards.view(id) }
            return view
        }
    }

    private var cardSize: (String) -> CGSize {
        let cards = cards
        return { id in MainActor.assumeIsolated { cards.size(id) } }
    }

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
            "value": SpotType.value,
            "card": cardView,
            "cardSize": cardSize
        ]
    }

    @ViewBuilder
    private var content: some View {
        switch views.phase(of: source) {
        case .building:
            EmptyView()
        case .ready(let make) where isShown:
            make(values, input, send ?? { _ in })
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
