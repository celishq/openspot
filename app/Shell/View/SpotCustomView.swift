import OpenspotCore
import SwiftUI

struct SpotCustomView: View, @MainActor Equatable {
    let source: String
    let values: [String: [String]]
    let card: SpotSize
    var room: CGSize?
    var answers = 0
    var date: Date?
    let views: SpotViews
    var send: ((String) -> Void)?
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotCards) private var cards
    @Environment(\.spotViewPlace) private var place
    @Environment(\.spotIsHeld) private var isHeld

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source == rhs.source && lhs.values == rhs.values && lhs.card == rhs.card && lhs.room == rhs.room && lhs.answers == rhs.answers && lhs.date == rhs.date && lhs.views === rhs.views
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
            .task(id: isHeld ? nil : loadKey) {
                if !isHeld { await views.load(source) }
            }
    }

    private var loadKey: String? {
        var hasFailed = false
        if case .failed = views.phase(of: source) { hasFailed = true }
        return "\(source)\n\(date?.timeIntervalSince1970 ?? 0)\n\(date == nil || hasFailed ? isShown : true)"
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

    private var sheetView: (String) -> AnyView {
        let cards = cards
        return { id in
            var view = AnyView(EmptyView())
            MainActor.assumeIsolated { view = cards.sheet(id) }
            return view
        }
    }

    private var tipView: (String) -> AnyView {
        { text in AnyView(SpotTipPill(text: text)) }
    }

    private var mediaView: (String) -> AnyView {
        { source in AnyView(SpotMedia(source: source)) }
    }

    private var cornerButton: (String, String, String, @escaping () -> Void) -> AnyView {
        let cards = cards
        return { symbol, label, id, action in
            var view = AnyView(EmptyView())
            MainActor.assumeIsolated { view = cards.cornerButton(symbol, label: label, card: id, action: action) }
            return view
        }
    }

    private var keep: () -> Void {
        let views = views
        let source = source
        return { MainActor.assumeIsolated { views.keep(source) } }
    }

    private var close: () -> Void {
        let place = place
        return { MainActor.assumeIsolated { place.close() } }
    }

    private var bodyTime: (Duration) -> Void {
        let place = place
        let source = source
        return { time in MainActor.assumeIsolated { place.drew(source, in: time) } }
    }

    private var input: [String: Any] {
        [
            "isShown": isShown,
            "keep": keep,
            "close": close,
            "bodyTime": bodyTime,
            "size": size,
            "answers": answers,
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
            "cardSize": cardSize,
            "sheet": sheetView,
            "tip": tipView,
            "media": mediaView,
            "cornerButton": cornerButton,
            "columnGap": SpotTokens.columnGap,
            "rowGap": SpotTokens.rowGap,
            "columns": SpotTokens.windowColumns,
            "tipDelay": SpotTipView.delay
        ]
    }

    @ViewBuilder
    private var content: some View {
        switch views.phase(of: source) {
        case .building:
            Color.clear
        case .ready(let make) where isShown || views.isKept(source):
            make(values, input, isHeld ? { _ in } : send ?? { _ in })
        case .ready:
            Color.clear
        case .failed(let reason):
            Text(reason)
                .font(SpotType.detail)
                .minimumScaleFactor(0.5)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondaryLight))
                .padding(SpotTokens.padding)
        }
    }
}
