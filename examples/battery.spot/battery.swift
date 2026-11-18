import SwiftUI

/// The battery as a liquid that fills the card from the bottom to its level, like a glass, with a surface that rolls
/// slowly. It is red when the battery runs low and green otherwise. The words turn white where the liquid covers them.
/// On power, a bolt shows and a few small bubbles rise. Openspot plays its motion, only while the card shows.
struct SpotView: View {
    let spot: SpotInput

    private var level: Double { min(1, max(0, Double(spot["value"] ?? "") ?? 0)) }
    private var isCharging: Bool { spot["tone"] == "good" }

    private var colors: [Color] {
        spot["tone"] == "bad" ? [Color(red: 1, green: 0.41, blue: 0.38), Color(red: 0.9, green: 0.2, blue: 0.16)]
            : [Color(red: 0.37, green: 0.88, blue: 0.48), Color(red: 0.16, green: 0.71, blue: 0.27)]
    }

    var body: some View {
        let level = level
        ZStack {
            spot.loop(period: Liquid.period, fill: colors[0], colors[1]) { time, rect in Liquid(time: time, level: level).path(in: rect) }
            spot.loop(period: Liquid.period, stroke: .white.opacity(0.55), width: 1) { time, rect in Liquid(time: time, level: level).surface.path(in: rect) }
            if isCharging {
                spot.loop(period: Bubbles.period, fill: .white.opacity(0.4)) { time, rect in Bubbles(time: time).path(in: rect) }
                    .clipShape(Liquid(time: 0, level: level))
            }
            words(over: false)
            words(over: true).clipShape(Liquid(time: 0, level: level))
        }
        .frame(width: spot.size.width, height: spot.size.height)
    }

    private func words(over: Bool) -> some View {
        SpotMetric(spot, value: spot["title"] ?? "–", detail: spot["detail"] ?? "", mark: isCharging ? "bolt.fill" : nil, onFill: over)
    }
}

/// The liquid at one moment: it fills the card from the bottom to its level, under a surface that rolls.
struct Liquid: Shape {
    let time: Double
    let level: Double

    /// The time after which the surface rolls the same way again.
    static let period = 20 * Double.pi

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

/// A few small bubbles that rise slowly through the card, as one path.
struct Bubbles: Shape {
    let time: Double

    /// The time after which each bubble is where it started.
    static let period = 20.0

    private static func hash(_ n: Double) -> Double {
        let value = sin(n * 12.9898) * 43758.5453
        return value - value.rounded(.down)
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<7 {
            let n = Double(index)
            let rise = time * Double(2 + index % 3) / Self.period + Self.hash(n + 7.7)
            let y = rect.height * (1.05 - (rise - rise.rounded(.down)) * 1.1)
            let x = 4 + Self.hash(n + 1.3) * max(rect.width - 8, 0) + 1.5 * sin(2 * .pi * 5 * time / Self.period + n)
            let radius = 1 + 1.4 * Self.hash(n + 5.9)
            path.addEllipse(in: CGRect(x: rect.minX + x - radius, y: rect.minY + y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}
