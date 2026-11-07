import SwiftUI
import OpenspotCore

/// A spot: a glyph, then a title with a detail, then an accessory. A small card shows the glyph alone, and a widget shows
/// its places. A kind differs only in what fills a slot: a slider has its track as its detail, and running work takes the
/// place of the glyph.
struct SpotCardView: View {
    let entry: SpotsModel.Entry
    let size: SpotSize
    let isSelected: Bool
    let takesDrag: Bool
    let isDropTarget: Bool
    let readings: [String: MetricReading]
    let chainLetter: String?
    let showsChain: Bool
    let isHiddenFromGrid: Bool
    let onTap: () -> Void
    let onLevel: (Double) -> Void
    @State private var isHovered = false
    @GestureState private var isPressed = false
    @Environment(\.spotIsShown) private var isShown

    /// How far a line reaches past the inset at its trailing end, where the round end of the card leaves room.
    private static let lineReach: CGFloat = 6

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
    }

    var body: some View {
        ZStack(alignment: .topLeading) { content }
            .padding(SpotTokens.cardPadding(for: size, isWidget: entry.kind == .widget))
            .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows), alignment: .topLeading)
            .background(shape.fill(Color.accentColor).opacity(dropFill))
            .modifier(SpotGlass(radius: SpotTokens.corner(for: size), isSolid: isFilled, strength: showsPress ? SpotMotion.pressedGlass : 1))
            .overlay(shape.fill((isFilled ? SpotTheme.onSolid : SpotTheme.ink).opacity(showsPress ? 0.12 : isHovered ? 0.08 : 0)).allowsHitTesting(false))
            .overlay(shape.strokeBorder(Color.accentColor, lineWidth: 2).animation(nil) { $0.opacity(isSelected ? 1 : 0) }.opacity(isShown ? 1 : 0).scaleEffect(isShown ? 1 : SpotMotion.hiddenScale).animation(SpotMotion.surface(isShown: isShown), value: isShown).allowsHitTesting(false))
            .overlay(alignment: .topTrailing) { keycap }
            .overlay(alignment: .topTrailing) { hiddenMark }
            .contentShape(shape)
            .onHover { isHovered = $0 }
            .onTapGesture(perform: onTap)
            .simultaneousGesture(DragGesture(minimumDistance: 0).updating($isPressed) { _, pressed, _ in pressed = true })
            .animation(.easeInOut(duration: 0.2), value: isOn)
            .scaleEffect(showsPress ? SpotMotion.pressedScale : 1)
            .animation(SpotMotion.press, value: showsPress)
    }

    @ViewBuilder
    private var content: some View {
        if let layout = entry.command.layout {
            SpotWidgetView(layout: layout, places: entry.command.places, readings: readings, card: size)
        } else if size == .small {
            glyph.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if size.rows > 1 {
            tile
        } else {
            row
        }
    }

    private var isOn: Bool {
        entry.state.on == true
    }

    private var showsPress: Bool {
        isPressed && entry.kind != .slider && (entry.kind != .widget || entry.command.opens != nil)
    }

    /// How strong the fill is: part of the way on a card that takes the drag, and full on the card that takes the drop.
    private var dropFill: Double {
        isDropTarget ? 1 : takesDrag ? SpotTheme.dragFill : 0
    }

    private var isFilled: Bool {
        isOn && dropFill == 0
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

    private var text: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            title
            if entry.kind == .slider {
                slider
            } else if let subtitle = entry.shownState.subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText(isOnSolid: isFilled))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch entry.kind {
        case .list:
            SpotCardArrow(isOnSolid: isFilled)
        case .launch:
            if size != .wide, !entry.stopsOnPress {
                Text("Run")
                    .font(SpotType.action)
                    .foregroundStyle(SpotTheme.ink.opacity(SpotTheme.titleOpacity))
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
            value: Binding(get: { entry.state.level ?? low }, set: { onLevel($0.rounded()) }),
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
        } else if let item = entry.item, item.icon != nil {
            SpotItemIcon(item: item, size: SpotTokens.glyphSize)
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
