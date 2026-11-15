import SwiftUI

/// The battery as the Mac once drew it, as big as the card: a glossy liquid fills the card from the left to its level,
/// and bubbles rise in it from the bottom. The number and the detail use the card's own type, and turn white where the
/// liquid covers them. A bolt shows while it charges. SwiftUI draws each frame on the GPU: `body` only describes the
/// shapes of the moment, and reads back no picture.
struct SpotView: View {
    let spot: SpotInput
    @State private var start = Date()

    private static let fill = 1.0

    private var level: Double { min(1, max(0, (Double(spot["title"] ?? "") ?? 0) / 100)) }
    private var isCharging: Bool { spot["state"] == "charging" }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { context in
            let time = context.date.timeIntervalSince(start)
            let liquid = Liquid(time: time, level: level * (1 - pow(1 - min(time / Self.fill, 1), 3)))
            ZStack(alignment: .leading) {
                liquid.fill(LinearGradient(colors: [liquid.color.opacity(0.95), liquid.color.mix(with: .black, by: 0.3)], startPoint: .top, endPoint: .bottom))
                liquid.fill(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.45)))
                Bubbles(liquid: liquid, count: isCharging ? 24 : 10)
                words.foregroundStyle(spot.ink)
                words.foregroundStyle(.white).clipShape(liquid)
            }
        }
        .onAppear { start = Date() }
    }

    private var words: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(spot["title"].map { "\($0)%" } ?? "–").font(spot.font.metric)
            if isCharging {
                Image(systemName: "bolt.fill").font(spot.font.detail)
            }
            Text(spot["detail"] ?? "").font(spot.font.detail).opacity(spot.secondary)
        }
        .padding(.horizontal, spot.inset + 6)
        .frame(width: spot.size.width, height: spot.size.height, alignment: .leading)
    }
}

/// The liquid at one moment: it fills the card from the left to its level, with an edge that sways.
struct Liquid: Shape {
    let time: Double
    let level: Double

    /// Red when low, then amber, then green.
    var color: Color {
        level < 0.1 ? Color(red: 0.93, green: 0.22, blue: 0.18) : level < 0.2 ? Color(red: 0.98, green: 0.66, blue: 0.10) : Color(red: 0.30, green: 0.78, blue: 0.22)
    }

    /// Where the edge is at a height from 0 at the top to 1 at the bottom, in points from the left.
    func edge(at y: Double, in rect: CGRect) -> Double {
        rect.width * level + rect.height * (0.03 * sin(y * 7 + time * 2.2) + 0.018 * sin(y * 13 - time * 3.4))
    }

    func path(in rect: CGRect) -> Path {
        guard level > 0 else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        let steps = 24
        for step in 0...steps {
            let y = Double(step) / Double(steps)
            path.addLine(to: CGPoint(x: rect.minX + max(0, edge(at: y, in: rect)), y: rect.minY + y * rect.height))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Bubbles that rise in the liquid, each a ring with a shine, drawn in one canvas.
struct Bubbles: View {
    let liquid: Liquid
    let count: Int

    private static func hash(_ n: Double) -> Double {
        let value = sin(n * 12.9898) * 43758.5453
        return value - value.rounded(.down)
    }

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let time = liquid.time
            for index in 0..<count {
                let n = Double(index)
                let speed = 0.35 + 0.45 * Self.hash(n + 3.1)
                let rise = time * speed + Self.hash(n + 7.7)
                let y = 1.1 - (rise - rise.rounded(.down))
                let edge = liquid.edge(at: y, in: rect)
                let radius = size.height * (0.035 + 0.04 * Self.hash(n + 5.9))
                let x = Self.hash(n + 1.3) * max(edge - 0.08 * size.height, 0) + size.height * (0.04 + 0.03 * sin(time * 3 + n * 2))
                guard x < edge - radius else { continue }
                let ring = CGRect(x: x - radius, y: y * size.height - radius, width: radius * 2, height: radius * 2)
                context.stroke(Path(ellipseIn: ring), with: .color(.white.opacity(0.45)), lineWidth: max(1, radius * 0.25))
                context.fill(Path(ellipseIn: ring.insetBy(dx: radius * 0.6, dy: radius * 0.6).offsetBy(dx: -radius * 0.35, dy: -radius * 0.35)), with: .color(.white.opacity(0.5)))
            }
        }
        .allowsHitTesting(false)
    }
}
