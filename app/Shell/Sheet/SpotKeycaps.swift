import OpenspotCore
import SwiftUI

struct SpotKeycaps: View {
    let value: String
    let held: Shortcut.Modifiers
    let isRecording: Bool
    let status: String?
    var pressed: String?
    var isKeyDown = false

    private static let caps: [(modifier: Shortcut.Modifiers, name: String)] = [
        (.control, "control"), (.option, "option"), (.shift, "shift"), (.command, "command")
    ]
    private static let side: CGFloat = 36
    private static let gap: CGFloat = 5
    private static let statusGap: CGFloat = 8
    private static let statusLines = 2
    private static let waiting = "Press the keys together."
    private static let symbolFont = Font.system(size: 15, weight: .medium)

    var body: some View {
        let shown = isRecording ? nil : Shortcut(text: value)
        let lit = isRecording ? held : shown?.modifiers ?? []
        let key = shown?.keyLabel ?? (isRecording ? pressed : nil)
        VStack(spacing: Self.statusGap) {
            HStack(spacing: Self.gap) {
                ForEach(Self.caps, id: \.name) { cap in
                    Keycap(symbol: cap.modifier.marks, name: cap.name, font: Self.symbolFont, width: Self.side, height: Self.side, isLit: lit.contains(cap.modifier))
                }
                Text("+")
                    .font(SpotType.body)
                    .modifier(SpotSecondaryText())
                Keycap(symbol: key ?? "key", name: "", font: key == nil ? SpotType.detail : SpotType.title, width: 2 * Self.side, height: Self.side, isLit: shown != nil || (pressed != nil && isKeyDown), isBlank: key == nil)
            }
            ToastView.styled(status ?? (isRecording ? Self.waiting : ""))
                .textRenderer(ToastKeyFill(fill: SpotTheme.ink.opacity(SpotTheme.track)))
                .font(SpotType.detail)
                .modifier(SpotSecondaryText())
                .multilineTextAlignment(.center)
                .lineLimit(Self.statusLines)
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(Self.statusLines) * SpotType.detailLine, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Keycap: View {
    let symbol: String
    let name: String
    let font: Font
    let width: CGFloat
    let height: CGFloat
    let isLit: Bool
    var isBlank = false

    private static let corner: CGFloat = 8
    private static let rim: CGFloat = 1
    private static let edge: CGFloat = 2.5
    private static let litEdge: CGFloat = 2
    private static let glow: CGFloat = 2.5
    private static let nameGap: CGFloat = 1
    private static let leastScale = 0.6
    private static let nameFont = Font.system(size: 8, weight: .medium)

    private var shape: SpotRoundShape {
        SpotRoundShape(radius: Self.corner)
    }

    var body: some View {
        ZStack {
            shape.fill(SpotTheme.capFace)
            KeycapEdge(face: shape, height: Self.edge).fill(SpotTheme.capEdge)
            shape.strokeBorder(SpotTheme.capRim, lineWidth: Self.rim)
            legend
                .modifier(SpotSecondaryText())
                .opacity(isBlank ? SpotTheme.capBlank : 1)
            ZStack {
                shape.inset(by: -Self.glow).strokeBorder(SpotTheme.accent.opacity(SpotTheme.capGlow), lineWidth: Self.glow)
                shape.fill(SpotTheme.accent)
                KeycapEdge(face: shape, height: Self.litEdge).fill(SpotTheme.capEdge)
                legend.foregroundStyle(SpotTheme.onAccent)
            }
            .animation(SpotMotion.press) { $0.opacity(isLit ? 1 : MotionTokens.hiddenOpacity) }
        }
        .frame(width: width, height: height)
    }

    private var legend: some View {
        VStack(spacing: Self.nameGap) {
            Text(symbol)
                .font(font)
            Text(name.isEmpty ? " " : name)
                .font(Self.nameFont)
        }
        .lineLimit(1)
        .minimumScaleFactor(Self.leastScale)
        .padding(.horizontal, Self.rim)
    }
}

private struct KeycapEdge: Shape {
    let face: SpotRoundShape
    let height: CGFloat

    func path(in rect: CGRect) -> Path {
        face.path(in: rect).subtracting(face.path(in: rect.offsetBy(dx: 0, dy: -height)))
    }
}
