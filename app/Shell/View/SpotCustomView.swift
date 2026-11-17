import OpenspotCore
import SwiftUI

struct SpotCustomView: View, @MainActor Equatable {
    let source: String
    let values: [String: [String]]
    var rows: [[String]] = []
    let card: SpotSize
    var room: CGSize?
    var answers = 0
    var selection: String?
    var date: Date?
    let views: SpotViews
    var send: ((String) -> Void)?
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotIsStill) private var isStill
    @Environment(\.spotCards) private var cards
    @Environment(\.spotViewPlace) private var place
    @Environment(\.spotIsHeld) private var isHeld
    @Environment(\.spotSurfaceEdge) private var surface
    @Environment(\.colorScheme) private var scheme

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.source == rhs.source && lhs.values == rhs.values && lhs.rows == rhs.rows && lhs.card == rhs.card && lhs.room == rhs.room && lhs.answers == rhs.answers && lhs.selection == rhs.selection && lhs.date == rhs.date && lhs.views === rhs.views
            && (lhs.send == nil) == (rhs.send == nil)
    }

    private var size: CGSize {
        room ?? CGSize(width: SpotTokens.width(columns: card.columns), height: SpotTokens.height(rows: card.rows))
    }

    private var corner: CGFloat {
        room == nil ? SurfaceEdge(card: card, mark: .view).radius : surface.inner().radius
    }

    var body: some View {
        content
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .clipShape(SpotRoundShape(radius: corner))
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
            "isShown": isShown && !isStill,
            "rows": rows,
            "selection": selection as Any,
            "close": close,
            "bodyTime": bodyTime,
            "size": size,
            "cardName": (room == nil ? card.name : nil) as Any,
            "answers": answers,
            "inset": SpotTokens.padding,
            "corner": corner,
            "ink": SpotTheme.ink,
            "secondary": SpotTheme.secondary,
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
            "tipDelay": SpotTipView.delay,
            "theme": theme
        ]
    }

    private var theme: [String: Any] {
        SpotLoadedTheme.shared.viewTheme(isDark: scheme == .dark, corner: corner)
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
                .minimumScaleFactor(SpotType.leastViewScale)
                .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.secondary))
                .padding(SpotTokens.padding)
        }
    }
}
