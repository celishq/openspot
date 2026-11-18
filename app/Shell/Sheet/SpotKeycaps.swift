import AppKit
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
    private static let side = SpotTokens.keycapSide
    private static let gap = SpotTokens.keycapGap
    private static let plus = SpotTokens.keycapPlus
    private static let hintGap = SpotTokens.keycapHintGap
    private static let hintLine = SpotTokens.keycapHintLine
    private static let statusGap = SpotTokens.keycapStatusGap
    private static let statusLines = 3
    private static let waiting = "Press the keys together."
    private static let idle = "Press Return to record a key."
    private static let modifierHint = "⌃, ⌥ or ⌘"
    private static let keyHint = "a key"
    private static let symbolFont = SpotType.keycapSymbol
    private static let keyFont = SpotType.keycapKey
    private static let arrivalScale = MotionTokens.keycapArrivalScale
    private static let arrival = AnyTransition.asymmetric(
        insertion: .scale(scale: arrivalScale).combined(with: .opacity).animation(SpotMotion.pop),
        removal: .scale(scale: arrivalScale).combined(with: .opacity).animation(SpotMotion.fade(isShown: false))
    )

    var body: some View {
        let shown = isRecording ? nil : Shortcut(text: value)
        VStack(spacing: Self.statusGap) {
            GeometryReader { room in
                let row = Self.row(of: caps(shown: shown), width: room.size.width)
                ZStack(alignment: .top) {
                    ForEach(row.caps) { placed in
                        cell(placed, side: row.side)
                            .transition(Self.arrival)
                            .offset(x: placed.center - room.size.width / 2)
                    }
                }
                .frame(width: room.size.width, height: room.size.height, alignment: .top)
                .animation(SpotMotion.move, value: row)
            }
            .frame(height: Self.side + Self.hintGap + Self.hintLine)
            Self.words(Self.shownWords(message(shown: shown)))
                .padding(.horizontal, Self.statusInset)
                .frame(maxWidth: .infinity)
                .frame(height: CGFloat(Self.statusLines) * SpotType.detailLine, alignment: .top)
                .offset(y: hasHints(shown: shown) ? 0 : -Self.hintRoom)
                .animation(SpotMotion.move, value: hasHints(shown: shown))
        }
        .frame(maxWidth: .infinity)
        .offset(y: drop(shown: shown))
        .animation(SpotMotion.move, value: drop(shown: shown))
    }

    private static let hintRoom = hintGap + hintLine
    private static let statusInset = SpotTokens.keycapStatusInset
    private static var statusWidth: CGFloat { SpotTokens.partsWidth - 2 * statusInset }

    private func message(shown: Shortcut?) -> String {
        isRecording ? status ?? Self.waiting : status ?? (shown == nil ? Self.idle : "")
    }

    @MainActor private static func shownWords(_ message: String) -> String {
        let split = sentenceLines(message)
        return split.split(separator: "\n").allSatisfy { lineCount(String($0)) == 1 } ? split : message
    }

    @MainActor private static func lineCount(_ message: String) -> Int {
        guard !message.isEmpty else { return 0 }
        let font = SpotType.detailMeasure
        let plain = message.replacingOccurrences(of: "`", with: "\u{2009}\u{2009}")
        let room = CGSize(width: statusWidth, height: .greatestFiniteMagnitude)
        let height = NSAttributedString(string: plain, attributes: [.font: font]).boundingRect(with: room, options: [.usesLineFragmentOrigin, .usesFontLeading]).height
        return max(Int((height / (font.ascender - font.descender + font.leading)).rounded()), 1)
    }

    private static func words(_ message: String) -> some View {
        ToastView.styled(message)
            .textRenderer(ToastKeyFill(fill: SpotTheme.ink.opacity(SpotTheme.track)))
            .font(SpotType.detail)
            .modifier(SpotSecondaryText())
            .multilineTextAlignment(.center)
            .lineLimit(statusLines)
    }

    private static func sentenceLines(_ message: String) -> String {
        message.replacing(/([.!?]) +(?=[A-Z`])/) { "\($0.1)\n" }
    }

    private func hasHints(shown: Shortcut?) -> Bool {
        let modifiers = isRecording ? held : shown?.modifiers ?? []
        let key = shown?.keyLabel ?? (isRecording && isKeyDown ? pressed : nil)
        return modifiers.isEmpty || key == nil
    }

    private func drop(shown: Shortcut?) -> CGFloat {
        let full = Self.side + Self.hintRoom + Self.statusGap + CGFloat(Self.statusLines) * SpotType.detailLine
        guard isRecording || shown == nil || status != nil else { return (full - Self.side) / 2 }
        let lines = Self.lineCount(Self.shownWords(message(shown: shown)))
        let seen = Self.side + (hasHints(shown: shown) ? Self.hintRoom : 0) + Self.statusGap + CGFloat(lines) * SpotType.detailLine
        return (full - seen) / 2
    }

    private func caps(shown: Shortcut?) -> [Cap] {
        let modifiers = isRecording ? held : shown?.modifiers ?? []
        let key = shown?.keyLabel ?? (isRecording && isKeyDown ? pressed : nil)
        let isRefused = isRecording && status != nil && (isKeyDown || !held.isEmpty)
        var caps = [Cap(id: "slot", isSlot: true, hint: Self.modifierHint, isShown: modifiers.isEmpty)]
        caps += Self.caps.map { cap in
            Cap(
                id: cap.name, symbol: cap.modifier.marks, name: cap.name, font: Self.symbolFont, units: KeyWidth.of(cap.modifier),
                isLit: !isRefused, isShown: modifiers.contains(cap.modifier)
            )
        }
        caps.append(Cap(id: "plus", units: 0, isPlus: true))
        caps.append(Cap(
            id: "key", symbol: key ?? "", font: Self.keyFont, units: key.map { KeyWidth.of(label: $0) } ?? 1,
            isLit: (shown != nil || isKeyDown) && !isRefused, isSlot: key == nil, hint: key == nil ? Self.keyHint : nil
        ))
        return caps
    }

    private static func row(of caps: [Cap], width: CGFloat) -> CapRow {
        let shown = caps.filter(\.isShown)
        let units = shown.reduce(0) { $0 + $1.units }
        let fixed = CGFloat(shown.filter(\.isPlus).count) * plus + CGFloat(max(shown.count - 1, 0)) * gap
        let side = max(min(Self.side, (width - fixed) / CGFloat(max(units, 1))), 1)
        var x = (width - side * CGFloat(units) - fixed) / 2
        let placed = shown.map { cap in
            let capWidth = cap.isPlus ? plus : side * CGFloat(cap.units)
            defer { x += capWidth + gap }
            return PlacedCap(cap: cap, center: x + capWidth / 2, width: capWidth)
        }
        return CapRow(side: side, caps: placed)
    }

    private func cell(_ placed: PlacedCap, side: CGFloat) -> some View {
        VStack(spacing: Self.hintGap) {
            Group {
                if placed.cap.isPlus {
                    Text("+")
                        .font(SpotType.body)
                        .modifier(SpotSecondaryText())
                } else {
                    Keycap(cap: placed.cap, size: CGSize(width: placed.width, height: side))
                }
            }
            .frame(width: Self.side * KeyWidth.widest, height: Self.side)
            Text(placed.cap.hint ?? " ")
                .font(SpotType.small)
                .modifier(SpotSecondaryText())
                .lineLimit(1)
                .frame(height: Self.hintLine)
        }
    }
}

private struct Cap: Equatable {
    let id: String
    var symbol = ""
    var name = ""
    var font = SpotType.body
    var units: Double = 1
    var isLit = false
    var isSlot = false
    var hint: String?
    var isPlus = false
    var isShown = true
}

private struct PlacedCap: Equatable, Identifiable {
    let cap: Cap
    let center: CGFloat
    let width: CGFloat

    var id: String {
        cap.id
    }
}

private struct CapRow: Equatable {
    let side: CGFloat
    let caps: [PlacedCap]
}

private struct Keycap: View {
    let cap: Cap
    let size: CGSize

    private static let corner = SpotTokens.keycapCorner
    private static let rim: CGFloat = 1
    private static let edge = SpotTokens.keycapEdge
    private static let litEdge = SpotTokens.keycapLitEdge
    private static let glow = SpotTokens.keycapGlow
    private static let dashLine = SpotTokens.keycapDashLine
    private static let dash: [CGFloat] = [4, 3]
    private static let nameGap: CGFloat = 1
    private static let leastScale = MotionTokens.keycapLeastScale
    private static let nameFont = SpotType.keycapName
    private static let legendScale = MotionTokens.keycapLegendScale
    private static let legendArrival = AnyTransition.scale(scale: legendScale).combined(with: .opacity).animation(SpotMotion.pop)

    @State private var isIn = false
    @Environment(\.spotIsHeld) private var isHeld

    var body: some View {
        let face = KeyFace(size: size, radius: Self.corner)
        ZStack {
            ZStack {
                face.fill(SpotTheme.capFace)
                KeycapEdge(face: face, height: Self.edge).fill(SpotTheme.capEdge)
                face.strokeBorder(SpotTheme.capRim, lineWidth: Self.rim)
                legend(face).modifier(SpotSecondaryText())
            }
            .opacity(cap.isSlot ? MotionTokens.hiddenOpacity : 1)
            face.strokeBorder(.secondary.opacity(SpotTheme.track), style: StrokeStyle(lineWidth: Self.dashLine, dash: Self.dash))
                .opacity(cap.isSlot ? 1 : MotionTokens.hiddenOpacity)
            ZStack {
                face.inset(by: -Self.glow).strokeBorder(SpotTheme.accent.opacity(SpotTheme.capGlow), lineWidth: Self.glow)
                face.fill(SpotTheme.accent)
                KeycapEdge(face: face, height: Self.litEdge).fill(SpotTheme.capEdge)
                legend(face).foregroundStyle(SpotTheme.onAccent)
            }
            .animation(SpotMotion.press) { $0.opacity(cap.isLit && !cap.isSlot ? 1 : MotionTokens.hiddenOpacity) }
        }
        .onAppear { withAnimation(SpotMotion.pop) { isIn = true } }
    }

    private func legend(_ face: KeyFace) -> some View {
        ZStack {
            VStack(spacing: Self.nameGap) {
                Text(cap.symbol)
                    .font(cap.font)
                if !cap.name.isEmpty {
                    Text(cap.name)
                        .font(Self.nameFont)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(Self.leastScale)
            .id(cap.symbol)
            .transition(Self.legendArrival)
        }
        .scaleEffect(isIn || isHeld ? 1 : Self.legendScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(face)
    }
}

private struct KeyFace: InsettableShape {
    var size: CGSize
    let radius: CGFloat
    var inset: CGFloat = 0

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size.width, size.height) }
        set { size = CGSize(width: newValue.first, height: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let face = CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
        return Path(roundedRect: face.insetBy(dx: inset, dy: inset), cornerRadius: max(radius - inset, 0), style: .continuous)
    }

    func inset(by amount: CGFloat) -> KeyFace {
        var face = self
        face.inset += amount
        return face
    }
}

private struct KeycapEdge: Shape {
    var face: KeyFace
    let height: CGFloat

    var animatableData: KeyFace.AnimatableData {
        get { face.animatableData }
        set { face.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        face.path(in: rect).subtracting(face.path(in: rect.offsetBy(dx: 0, dy: -height)))
    }
}
