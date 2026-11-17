import SwiftUI

/// The battery as a liquid that fills the card from the bottom to its level, like a glass, with a surface that rolls
/// slowly. The words turn white where the liquid covers them. While it charges, a bolt shows and a few small bubbles
/// rise. It moves only while the panel shows it.
struct SpotView: View {
    let spot: SpotInput
    @State private var start = Date()

    private static let fill = 1.1

    private var level: Double { min(1, max(0, (Double(spot["title"] ?? "") ?? 0) / 100)) }
    private var isCharging: Bool { spot["state"] == "charging" }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !spot.isShown)) { context in
            let time = context.date.timeIntervalSince(start)
            let liquid = Liquid(time: time, level: spot.isShown ? level * (1 - pow(1 - min(time / Self.fill, 1), 3)) : level)
            ZStack {
                liquid.fill(LinearGradient(colors: liquid.colors, startPoint: .top, endPoint: .bottom))
                liquid.surface.stroke(.white.opacity(0.55), lineWidth: 1)
                if isCharging {
                    Bubbles(time: time).clipShape(liquid)
                }
                words(over: false)
                words(over: true).clipShape(liquid)
            }
        }
        .frame(width: spot.size.width, height: spot.size.height)
        .onAppear { start = Date() }
    }

    private func words(over: Bool) -> some View {
        let number = Text(spot["title"].map { "\($0)%" } ?? "–")
            .font(spot.card == .small ? .system(size: 18, weight: .semibold, design: .rounded) : spot.font.metric)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .layoutPriority(1)
        let detail = HStack(spacing: 3) {
            if spot.card != .wide {
                Text(spot["detail"] ?? "")
            }
            if isCharging {
                Image(systemName: "bolt.fill")
            }
        }
        .font(spot.font.detail)
        .lineLimit(1)
        .opacity(over ? 1 : spot.secondary)
        return Group {
            switch spot.card {
            case .small:
                number.frame(maxWidth: .infinity, maxHeight: .infinity)
            case .wide, .strip:
                HStack(alignment: .firstTextBaseline, spacing: 8) { number; detail }
                    .padding(.horizontal, spot.inset + 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            default:
                VStack(alignment: .leading, spacing: 2) { number; detail }
                    .padding(spot.inset + 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .foregroundStyle(over ? .white : spot.ink)
    }
}

/// The liquid at one moment: it fills the card from the bottom to its level, under a surface that rolls.
struct Liquid: Shape {
    let time: Double
    let level: Double

    /// Red when low, then amber, then green, each lighter at the top.
    var colors: [Color] {
        level < 0.1 ? [Color(red: 1, green: 0.41, blue: 0.38), Color(red: 0.9, green: 0.2, blue: 0.16)]
            : level < 0.2 ? [Color(red: 1, green: 0.75, blue: 0.3), Color(red: 0.95, green: 0.57, blue: 0)]
            : [Color(red: 0.37, green: 0.88, blue: 0.48), Color(red: 0.16, green: 0.71, blue: 0.27)]
    }

    /// The line of the surface alone.
    var surface: Surface { Surface(liquid: self) }

    /// The height of the surface at a point across, from 0 on the left to 1 on the right, in points from the top.
    func top(at x: Double, in rect: CGRect) -> Double {
        let wave = min(rect.height * 0.035, 3.2) * (sin(x * 6.28 + time * 1.3) + 0.5 * sin(x * 11 - time * 1.9))
        return rect.height * (1 - level) + wave
    }

    func path(in rect: CGRect) -> Path {
        guard level > 0 else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        let steps = 32
        for step in 0...steps {
            let x = Double(step) / Double(steps)
            path.addLine(to: CGPoint(x: rect.minX + x * rect.width, y: rect.minY + top(at: x, in: rect)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The rolling line on top of the liquid.
struct Surface: Shape {
    let liquid: Liquid

    func path(in rect: CGRect) -> Path {
        guard liquid.level > 0 else { return Path() }
        var path = Path()
        let steps = 32
        for step in 0...steps {
            let x = Double(step) / Double(steps)
            let point = CGPoint(x: rect.minX + x * rect.width, y: rect.minY + liquid.top(at: x, in: rect) + 0.5)
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        return path
    }
}

/// A few small bubbles that rise slowly through the card, drawn in one canvas.
struct Bubbles: View {
    let time: Double

    private static func hash(_ n: Double) -> Double {
        let value = sin(n * 12.9898) * 43758.5453
        return value - value.rounded(.down)
    }

    var body: some View {
        Canvas { context, size in
            for index in 0..<7 {
                let n = Double(index)
                let rise = time * (0.12 + 0.12 * Self.hash(n + 3.1)) + Self.hash(n + 7.7)
                let y = size.height * (1.05 - (rise - rise.rounded(.down)) * 1.1)
                let x = 4 + Self.hash(n + 1.3) * max(size.width - 8, 0) + 1.5 * sin(time * 1.5 + n)
                let radius = 1 + 1.4 * Self.hash(n + 5.9)
                let ring = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                context.fill(ring, with: .color(.white.opacity(0.35)))
                context.stroke(ring, with: .color(.white.opacity(0.5)), lineWidth: 0.6)
            }
        }
        .allowsHitTesting(false)
    }
}
