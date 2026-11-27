import OpenspotCore
import SwiftUI

struct NodeLook: ViewModifier {
    let style: Style
    var drawsFill = true
    @Environment(\.spotSurfaceEdge) private var surface
    @Environment(\.spotIsOnSolid) private var isOnSolid

    func body(content: Content) -> some View {
        let shape = shape
        content
            .transformEnvironment(\.font) { [style] font in
                if let face = style.font { font = Self.font(face) }
                if let weight = style.weight { font = (font ?? SpotType.body).weight(Self.weight(weight)) }
                if style.tabularNumbers { font = (font ?? SpotType.body).monospacedDigit() }
            }
            .transformEnvironment(\.multilineTextAlignment) { [style] alignment in
                if let chosen = style.textAlignment { alignment = Self.alignment(chosen) }
            }
            .transformEnvironment(\.lineLimit) { [style] limit in
                if style.truncates { limit = 1 } else if let lines = style.lineLimit { limit = lines }
            }
            .modifier(NodeInk(ink: style.ink))
            .padding(insets)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: horizontal, vertical: .top))
            .background {
                if style.blursBackdrop { shape.fill(.regularMaterial) }
                if drawsFill, let fill = style.fill { shape.fill(Self.colour(fill, onSolid: isOnSolid)) }
            }
            .overlay {
                if style.hasBorder { shape.strokeBorder(SpotTheme.ink(onSolid: isOnSolid).opacity(SpotTheme.track), lineWidth: SpotTokens.nodeBorder) }
            }
            .modifier(NodeClip(shape: shape, clips: style.clips))
            .opacity(style.opacity ?? 1)
    }

    private var shape: SpotRoundShape {
        switch style.corner {
        case .card: SpotRoundShape(radius: SpotTokens.cardRadius)
        case .inner: SpotRoundShape(surface.inner())
        case .full: SpotRoundShape(radius: .infinity)
        case .some(.none), nil: SpotRoundShape(radius: 0)
        }
    }

    private var insets: EdgeInsets {
        let side = { (edge: Style.Edge) in style.padding[edge]?.points(of: 0) ?? 0 }
        return EdgeInsets(top: side(.top), leading: side(.left), bottom: side(.bottom), trailing: side(.right))
    }

    private var horizontal: HorizontalAlignment {
        switch style.textAlignment {
        case .left, nil: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    private static func font(_ face: Style.Font) -> Font {
        switch face {
        case .title, .section: SpotType.title
        case .detail: SpotType.detail
        case .metric: SpotType.metric
        case .value: SpotType.value
        }
    }

    private static func weight(_ weight: Style.Weight) -> Font.Weight {
        switch weight {
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    private static func alignment(_ alignment: Style.TextAlignment) -> TextAlignment {
        switch alignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
    }

    @MainActor private static func colour(_ fill: Style.Fill, onSolid: Bool) -> SpotColor {
        switch fill {
        case .tile: SpotTheme.ink(onSolid: onSolid).opacity(SpotTheme.fill)
        case .accent: SpotTheme.accent
        case .good: SpotTheme.good
        case .warn: SpotTheme.warn
        case .bad: SpotTheme.bad
        case .transparent: .clear
        }
    }
}

private struct NodeInk: ViewModifier {
    let ink: Style.Ink?

    func body(content: Content) -> some View {
        switch ink {
        case nil: content
        case .ink: content.modifier(SpotInk())
        case .secondary: content.modifier(SpotSecondaryText())
        case .accent: content.foregroundStyle(SpotTheme.accent)
        case .good: content.foregroundStyle(SpotTheme.good)
        case .warn: content.foregroundStyle(SpotTheme.warn)
        case .bad: content.foregroundStyle(SpotTheme.bad)
        }
    }
}

private struct NodeClip: ViewModifier {
    let shape: SpotRoundShape
    let clips: Bool

    func body(content: Content) -> some View {
        if clips { content.clipShape(shape) } else { content }
    }
}
