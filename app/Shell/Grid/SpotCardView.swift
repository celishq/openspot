import SwiftUI
import OpenspotCore

/// A spot: a glyph, then a title with a detail, then an accessory. A small card shows the glyph alone, and a widget shows
/// its places. A kind differs only in what fills a slot: a slider has its track as its detail, and running work takes the
/// place of the glyph.
struct SpotCardView: View, Equatable {
    let entry: SpotsModel.Entry
    let size: SpotSize
    /// The card's place among the visible cards, which its ring compares with the selection.
    let index: Int
    /// Whether the person presses the card, which the grid follows so that its blur grows with the card.
    let isPressed: Bool
    let takesDrag: Bool
    let isDropTarget: Bool
    let chainLetter: String?
    let showsChain: Bool
    let isHiddenFromGrid: Bool
    /// The model that a tap and a slide go to.
    let model: SpotsModel
    @State private var isHovered = false
    @Environment(\.spotIsShown) private var isShown

    /// Whether two cards show the same values, so that a run of the grid reruns only the cards that changed.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry && lhs.size == rhs.size && lhs.index == rhs.index && lhs.isPressed == rhs.isPressed
            && lhs.takesDrag == rhs.takesDrag && lhs.isDropTarget == rhs.isDropTarget && lhs.chainLetter == rhs.chainLetter
            && lhs.showsChain == rhs.showsChain && lhs.isHiddenFromGrid == rhs.isHiddenFromGrid && lhs.model === rhs.model
    }

    /// How far a line reaches past the inset at its trailing end, where the round end of the card leaves room.
    private static let lineReach: CGFloat = 6

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topLeading) { content }
            .padding(drawnView != nil && !isDrawn ? 0 : SpotTokens.cardPadding(for: size, isWidget: entry.kind == .widget || isDrawn))
            .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows), alignment: .topLeading)
            .background(shape.fill(SpotTheme.accent).opacity(dropFill))
            .modifier(SpotGlass(radius: SpotTokens.corner(for: size), isSolid: isFilled, blursBehind: false, rimSize: CGSize(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows))))
            .overlay(shape.fill((isFilled ? SpotTheme.onSolid : SpotTheme.ink).opacity(showsPress ? 0.12 : isHovered ? 0.08 : 0)).allowsHitTesting(false))
            .overlay(Color.clear.modifier(CardRing(model: model, index: index, shape: shape)).opacity(isShown ? 1 : 0).scaleEffect(isShown ? 1 : SpotMotion.hiddenScale).animation(SpotMotion.surface(isShown: isShown), value: isShown).allowsHitTesting(false))
            .overlay(alignment: .topTrailing) { keycap }
            .overlay(alignment: .topTrailing) { hiddenMark }
            .overlay(alignment: .topTrailing) { if !isHiddenFromGrid { FailureMark(entry: entry, size: size) } }
            .contentShape(shape)
            .onHover { isHovered = $0 }
            .onTapGesture { model.tap(entry.id) }
            .animation(.easeInOut(duration: 0.2), value: isOn)
            .scaleEffect(showsPress ? SpotMotion.pressedScale : 1)
            .animation(SpotMotion.press, value: showsPress)
            .task(id: ownView.map { "\($0)\n\(isShown)" }) {
                if let ownView { await SpotViews.shared.load(ownView) }
            }
    }

    @ViewBuilder
    private var content: some View {
        if entry.item == nil, let layout = entry.state.face.layout(for: size) {
            SpotCardDrawing(layout: layout, face: entry.state.face, card: size, reading: reading, view: { room in
                drawnView.map { SpotCustomView(source: $0, values: entry.state.values, card: size, room: room, views: SpotViews.shared) }
            }) { model.setCardPart(entry.id, $0, to: $1) }
        } else if let view = drawnView {
            SpotCustomView(source: view, values: entry.state.values, card: size, views: SpotViews.shared)
        } else if let layout = entry.command.layout {
            SpotWidgetView(layout: layout, places: entry.command.places, reading: reading, card: size)
        } else if size == .small {
            glyph.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if size.rows > 1 {
            tile
        } else {
            row
        }
    }

    /// What each script last gave a widget to draw. Only a widget reads it.
    private var reading: (String) -> MetricReading? {
        entry.kind == .widget ? { [model] in model.reading(of: $0) } : { _ in nil }
    }

    /// The source of the plugin's own view, which fills the whole card in place of its glyph and words (V3).
    private var ownView: String? {
        entry.item == nil && entry.state.face.hasView ? entry.command.view : nil
    }

    /// The source of the plugin's own view once it is built or has failed. While it builds, the card is drawn as any card
    /// with running work.
    private var drawnView: String? {
        guard let ownView else { return nil }
        if case .building = SpotViews.shared.phase(of: ownView) { return nil }
        return ownView
    }

    /// Whether its script draws the card from a drawing for its size (U5).
    private var isDrawn: Bool {
        entry.item == nil && entry.state.face.layout(for: size) != nil
    }

    private var isBuildingView: Bool {
        ownView != nil && drawnView == nil
    }

    private var isOn: Bool {
        entry.state.on == true
    }

    private var showsPress: Bool {
        isPressed && Self.showsPress(of: entry)
    }

    /// Whether a press shows on a card: a slider takes its own drags, and a widget that opens nothing has no press.
    static func showsPress(of entry: SpotsModel.Entry) -> Bool {
        entry.kind != .slider && (entry.kind != .widget || entry.command.opens != nil)
    }

    /// How strong the fill is: part of the way on a card that takes the drag, and full on the card that takes the drop.
    private var dropFill: Double {
        isDropTarget ? 1 : takesDrag ? SpotTheme.dragFill : 0
    }

    private var isFilled: Bool {
        Self.isFilled(entry, takesDrag: takesDrag, isDropTarget: isDropTarget)
    }

    /// Whether a card draws the solid fill of a spot that is on, which no drag or drop tints.
    static func isFilled(_ entry: SpotsModel.Entry, takesDrag: Bool, isDropTarget: Bool) -> Bool {
        entry.state.on == true && !takesDrag && !isDropTarget
    }

    private var row: some View {
        HStack(spacing: SpotTokens.padding - 5) {
            glyph
            text
                .frame(maxWidth: .infinity, alignment: .leading)
            accessory
        }
        .padding(.trailing, -Self.lineReach)
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
            .foregroundStyle(isFilled ? SpotTheme.onSolid : SpotTheme.ink)
            .lineLimit(1)
    }

    private func detail(_ text: String, isOnSolid: Bool) -> some View {
        Text(text)
            .font(SpotType.detail)
            .modifier(SpotSecondaryText(isOnSolid: isOnSolid))
            .lineLimit(1)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            title
            if entry.kind == .slider {
                slider
            } else if isBuildingView {
                detail("Building its view", isOnSolid: false)
            } else if let subtitle = entry.shownState.subtitle {
                detail(subtitle, isOnSolid: isFilled)
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch entry.kind {
        case .list:
            SpotCardArrow(isOnSolid: isFilled)
        case .launch:
            if size != .wide, entry.item == nil, !entry.stopsOnPress {
                Text("Run")
                    .font(SpotType.action)
                    .foregroundStyle(SpotTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(SpotTheme.ink.opacity(SpotTheme.chip), in: Capsule())
            }
        case .toggle, .slider, .widget:
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
        if let call = entry.work {
            SpotWorkMark(call: call, stops: entry.stopsOnPress, isOnSolid: isFilled)
        } else if isBuildingView || entry.isBuilding {
            SpotWorkMark(call: nil, isOnSolid: isFilled)
        } else if let item = entry.item, item.icon != nil {
            SpotItemIcon(item: item, size: SpotTokens.glyphSize)
        } else if entry.showsHeaderPicture {
            SpotItemIcon(icon: entry.command.icon, glyph: entry.command.glyph, symbol: nil, size: SpotTokens.glyphSize)
        } else {
            symbolGlyph
        }
    }

    /// The letter of the spot, on the rim of its top right corner.
    @ViewBuilder
    private var keycap: some View {
        if let chainLetter {
            let inset = SpotTokens.corner(for: size) * SpotTokens.rimPoint - SpotTokens.keycap / 2
            Text(chainLetter)
                .font(SpotType.keycap)
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.keycap, height: SpotTokens.keycap)
                .background(SpotTheme.keycap, in: RoundedRectangle(cornerRadius: SpotTokens.keycapRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SpotTokens.keycapRadius, style: .continuous).strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                .offset(x: -inset, y: inset)
                .opacity(showsChain ? 1 : 0)
                .animation(SpotMotion.keycap, value: showsChain)
                .allowsHitTesting(false)
        }
    }

    /// The mark that says Edit Spots shows this card and the grid does not.
    @ViewBuilder
    private var hiddenMark: some View {
        if isHiddenFromGrid {
            let inset = SpotTokens.corner(for: size) * SpotTokens.rimPoint - SpotTokens.keycap / 2
            Image(systemName: "eye.slash")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.keycap, height: SpotTokens.keycap)
                .background(SpotTheme.keycap, in: RoundedRectangle(cornerRadius: SpotTokens.keycapRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SpotTokens.keycapRadius, style: .continuous).strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                .offset(x: -inset, y: inset)
                .allowsHitTesting(false)
        }
    }

    private var symbolGlyph: some View {
        Image(systemName: entry.symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isFilled ? SpotTheme.glyphOnSolid : SpotTheme.ink)
            .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
            .background(glyphDisc, in: Circle())
    }
}

/// The ring of a selected card. It alone reads the selection, so that an arrow press reruns the rings and no card.
private struct CardRing: ViewModifier {
    let model: SpotsModel
    let index: Int
    let shape: RoundedRectangle

    func body(content: Content) -> some View {
        content.modifier(SpotSelectionRing(isSelected: model.selected == index, shape: shape))
    }
}

/// The mark of a spot whose last call failed, on the rim of its top right corner, until a call ends well. It alone reads
/// the failure, so that a failure reruns the mark and no card.
private struct FailureMark: View {
    let entry: SpotsModel.Entry
    let size: SpotSize

    var body: some View {
        if entry.failure != nil {
            let inset = SpotTokens.corner(for: size) * SpotTokens.rimPoint - SpotTokens.keycap / 2
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(SpotTheme.ink)
                .frame(width: SpotTokens.keycap, height: SpotTokens.keycap)
                .background(SpotTheme.keycap, in: RoundedRectangle(cornerRadius: SpotTokens.keycapRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: SpotTokens.keycapRadius, style: .continuous).strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                .offset(x: -inset, y: inset)
                .accessibilityLabel("Last run failed")
                .allowsHitTesting(false)
        }
    }
}
