import SwiftUI
import OpenspotCore

/// A spot: a glyph, then a title with a detail, then an accessory. A small card shows the glyph alone,
/// and a slider shows its title over its track.
struct SpotCardView: View {
    let entry: SpotsModel.Entry
    let size: SpotSize
    let isSelected: Bool
    let onTap: () -> Void
    let onLevel: (Double) -> Void
    @State private var isHovered = false
    @GestureState private var isPressed = false
    @Environment(\.spotIsShown) private var isShown

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: SpotTokens.corner(for: size), style: .continuous)
    }

    var body: some View {
        content
            .padding(SpotTokens.padding)
            .frame(width: SpotTokens.width(columns: size.columns), height: SpotTokens.height(rows: size.rows), alignment: .topLeading)
            .modifier(SpotGlass(radius: SpotTokens.corner(for: size), isSolid: isFilled, strength: showsPress ? SpotMotion.pressedGlass : 1))
            .overlay(shape.fill((isFilled ? Color.black : Color.white).opacity(showsPress ? 0.12 : isHovered ? 0.08 : 0)).allowsHitTesting(false))
            .overlay(shape.strokeBorder(Color.accentColor, lineWidth: 2).opacity(isSelected && isShown ? 1 : 0).scaleEffect(isShown ? 1 : SpotMotion.hiddenScale).animation(SpotMotion.surface(isShown: isShown), value: isShown).allowsHitTesting(false))
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
        if entry.kind == .slider {
            sliderBody
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
        isPressed && entry.kind != .slider
    }

    private var isFilled: Bool {
        isOn
    }

    private var row: some View {
        HStack(spacing: SpotTokens.padding - 5) {
            glyph
            text
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, entry.kind == .list || size == .wide ? -SpotTokens.columnGap : 0)
            accessory
        }
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
        Text(entry.state.title)
            .font(SpotType.title)
            .foregroundStyle(isFilled ? Color.black.opacity(SpotTokens.titleOpacity) : Color.white.opacity(SpotTokens.titleOpacity))
            .lineLimit(1)
    }

    private var text: some View {
        VStack(alignment: .leading, spacing: SpotType.lineGap) {
            title
            if let subtitle = entry.state.subtitle {
                Text(subtitle)
                    .font(SpotType.detail)
                    .modifier(SpotSecondaryText(isOnWhite: isFilled))
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var accessory: some View {
        switch entry.kind {
        case .list:
            Image(systemName: "chevron.right")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(isFilled ? Color.black : Color.white)
                .padding(.trailing, -6)
        case .launch:
            if size != .wide {
                Text("Run")
                    .font(SpotType.action)
                    .foregroundStyle(.white.opacity(SpotTokens.titleOpacity))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.25), in: Capsule())
            }
        case .toggle, .slider:
            EmptyView()
        }
    }

    private var sliderBody: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
            HStack(spacing: 10) {
                Image(systemName: entry.symbol)
                    .font(.system(size: 11, weight: .medium))
                slider
                Image(systemName: entry.symbol)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 3)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var slider: some View {
        let low = entry.state.min ?? 0
        let high = entry.state.max ?? 100
        return Slider(
            value: Binding(get: { entry.state.level ?? low }, set: { onLevel($0.rounded()) }),
            in: low...high
        )
        .controlSize(.small)
        .tint(.white)
        .sliderThumbVisibility(.hidden)
    }

    private var glyphDisc: Color {
        size == .small || isOn ? .clear : .white.opacity(0.2)
    }

    @ViewBuilder
    private var glyph: some View {
        if let item = entry.item, item.icon != nil {
            SpotItemIcon(item: item, size: SpotTokens.glyphSize)
        } else {
            symbolGlyph
        }
    }

    private var symbolGlyph: some View {
        Image(systemName: entry.symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isOn ? Color.accentColor : Color.white)
            .frame(width: SpotTokens.glyphSize, height: SpotTokens.glyphSize)
            .background(glyphDisc, in: Circle())
    }
}
