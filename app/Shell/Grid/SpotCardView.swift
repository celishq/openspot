import SwiftUI
import OpenspotCore

struct SpotCardView: View, @MainActor Equatable {
    let entry: SpotsModel.Entry
    let size: SpotSize
    let index: Int
    let isPressed: Bool
    let takesDrag: Bool
    let isDropTarget: Bool
    let model: SpotsModel
    var onTap: (() -> Void)?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry && lhs.size == rhs.size && lhs.index == rhs.index && lhs.isPressed == rhs.isPressed
            && lhs.takesDrag == rhs.takesDrag && lhs.isDropTarget == rhs.isDropTarget
            && lhs.model === rhs.model
    }

    private func shape(of mark: CardMark) -> SpotRoundShape {
        SpotRoundShape(SurfaceEdge(card: size, mark: mark))
    }

    var body: some View {
        ZStack(alignment: .topLeading) { content }
            .environment(\.spotIsOnSolid, isFilled)
            .environment(\.spotViewPlace, SpotViewPlace(model: model))
            .padding(drawnView != nil && !isDrawn ? 0 : SpotTokens.cardPadding(for: size, isWidget: entry.kind == .widget || isDrawn))
            .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows), alignment: .topLeading)
            .background(shape(of: .dropFill).fill(SpotTheme.accent).opacity(dropFill))
            .modifier(CardPress(shape: shape(of: .press), isFilled: isFilled, showsPress: showsPress))
            .modifier(SpotPointerMove { model.point(at: .card(entry.id)) })
            .overlay(Color.clear.modifier(CardRing(model: model, index: index, shape: shape(of: .ring))).allowsHitTesting(false))
            .overlay(alignment: .topTrailing) { FailureMark(entry: entry, size: size) }
            .modifier(SpotGlass(shape: shape(of: .glass), isSolid: isFilled))
            .contentShape(shape(of: .hit))
            .onTapGesture { if let onTap { onTap() } else { model.tap(entry.id, opening: NSEvent.modifierFlags.contains(.command)) } }
            .animation(SpotMotion.fade(isShown: isFilled), value: isFilled)
            .scaleEffect(showsPress ? MotionTokens.pressedScale : 1)
            .animation(SpotMotion.press, value: showsPress)
    }

    @ViewBuilder
    private var content: some View {
        if drawsOwnCard, let layout = entry.state.face.layout(for: size) {
            SpotCardDrawing(layout: layout, face: entry.state.face, card: size, view: { room in
                ownView.map { SpotCustomView(source: $0, values: entry.state.values, card: size, room: room, date: entry.spot.viewDate, views: SpotViews.shared) }
            }) { model.setCardPart(entry.id, $0, to: $1) }
        } else if let view = drawnView {
            SpotCustomView(source: view, values: entry.state.values, card: size, date: entry.spot.viewDate, views: SpotViews.shared)
        } else {
            words.background {
                if let ownView { SpotCustomView(source: ownView, values: entry.state.values, card: size, date: entry.spot.viewDate, views: SpotViews.shared) }
            }
        }
    }

    @ViewBuilder
    private var words: some View {
        if let layout = entry.spot.layout {
            SpotWidgetView(layout: layout, places: entry.spot.places, reading: reading, card: size)
        } else if size == .small {
            glyph.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if size.rows > 1 {
            tile
        } else {
            row
        }
    }

    private var reading: (String) -> MetricReading? {
        entry.kind == .widget ? { [model] in model.reading(of: $0) } : { _ in nil }
    }

    private var ownView: String? {
        drawsOwnCard && entry.state.face.hasView ? entry.spot.view : nil
    }

    private var drawnView: String? {
        guard let ownView else { return nil }
        if case .building = SpotViews.shared.phase(of: ownView) { return nil }
        return ownView
    }

    private var isDrawn: Bool {
        drawsOwnCard && entry.state.face.layout(for: size) != nil
    }

    private var drawsOwnCard: Bool {
        entry.item == nil || entry.item?.card != nil
    }

    private var isBuildingView: Bool {
        ownView != nil && drawnView == nil
    }

    private var showsPress: Bool {
        isPressed && Self.showsPress(of: entry)
    }

    static func showsPress(of entry: SpotsModel.Entry) -> Bool {
        entry.kind != .slider && (entry.kind != .widget || entry.spot.opens != nil)
    }

    private var dropFill: Double {
        isDropTarget ? 1 : takesDrag ? SpotTheme.dragFill : 0
    }

    private var isFilled: Bool {
        Self.isFilled(entry, takesDrag: takesDrag, isDropTarget: isDropTarget)
    }

    static func isFilled(_ entry: SpotsModel.Entry, takesDrag: Bool, isDropTarget: Bool) -> Bool {
        entry.isActive && !takesDrag && !isDropTarget
    }

    private var row: some View {
        HStack(spacing: SpotTokens.wordsGap) {
            glyph
            text
                .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(.trailing, -SpotTokens.cardLineReach)
        .frame(maxHeight: .infinity)
    }

    private var tile: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                glyph
                Spacer()
                accessory
            }
            Spacer(minLength: 0)
            text
        }
    }

    private var title: some View {
        Text(entry.shownState.title)
            .font(SpotType.title)
            .modifier(SpotInk())
            .lineLimit(1)
    }

    private func detail(_ text: String) -> some View {
        Text(text)
            .font(SpotType.detail)
            .modifier(SpotSecondaryText())
            .lineLimit(1)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            title
            if entry.kind == .slider {
                slider
            } else if isBuildingView {
                detail("Building its view")
            } else if let subtitle = entry.shownState.subtitle {
                detail(subtitle)
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch entry.kind {
        case .list where entry.spot.opensOnReturn:
            SpotCardArrow()
        case .list, .launch, .toggle, .slider, .widget:
            EmptyView()
        }
    }

    private var slider: some View {
        let low = entry.state.min ?? 0
        let high = entry.state.max ?? 100
        return Slider(
            value: Binding(get: { entry.state.level ?? low }, set: { model.setLevel(entry.id, to: $0.rounded()) }),
            in: low...high
        )
        .controlSize(.small)
        .tint(SpotTheme.ink)
        .sliderThumbVisibility(.hidden)
    }

    private var glyphDisc: Color {
        size == .small || isFilled ? .clear : SpotTheme.ink.opacity(SpotTheme.disc)
    }

    @ViewBuilder
    private var glyph: some View {
        if let item = entry.item, item.icon != nil {
            SpotItemIcon(item: item, size: SpotTokens.glyphSize)
        } else if entry.showsHeaderPicture {
            SpotItemIcon(icon: entry.spot.fileIcon, glyph: entry.spot.glyph, symbol: nil, size: SpotTokens.glyphSize)
        } else {
            symbolGlyph
        }
    }

    private var symbolGlyph: some View {
        Image(systemName: entry.symbol)
            .font(SpotType.glyph)
            .foregroundStyle(isFilled ? AnyShapeStyle(SpotTheme.glyphOnSolid) : AnyShapeStyle(SpotTheme.glassInk))
            .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
            .background(glyphDisc, in: Circle())
    }
}

private struct CardRing: ViewModifier {
    let model: SpotsModel
    let index: Int
    let shape: SpotRoundShape

    func body(content: Content) -> some View {
        content.modifier(SpotSelectionRing(isSelected: model.selected == index, shape: shape, marksMenu: model.openSheetID == nil))
    }
}

private struct CardPress: ViewModifier {
    let shape: SpotRoundShape
    let isFilled: Bool
    let showsPress: Bool

    func body(content: Content) -> some View {
        content
            .overlay(shape.fill((isFilled ? SpotTheme.onSolid : SpotTheme.ink).opacity(showsPress ? SpotTheme.pressFill : 0)).allowsHitTesting(false))
            .contentShape(shape)
    }
}

private struct FailureMark: View {
    let entry: SpotsModel.Entry
    let size: SpotSize

    var body: some View {
        if entry.failure != nil {
            let inset = SurfaceEdge(card: size).rim - SpotTokens.cornerMark / 2
            let cap = SpotRoundShape(radius: SpotTokens.cornerMarkRadius)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(SpotType.cornerFault)
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.cornerMark, height: SpotTokens.cornerMark)
                .background(SpotTheme.cornerFill, in: cap)
                .overlay(cap.strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                .offset(x: -inset, y: inset)
                .accessibilityLabel("Last run failed")
                .allowsHitTesting(false)
        }
    }
}
