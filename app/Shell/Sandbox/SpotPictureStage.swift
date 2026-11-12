import OpenspotCore
import SwiftUI

/// The ground of a picture of the guide: a drawn wallpaper, and over it a surface of the panel's glass, a blur of the
/// wallpaper through its shape with the panel's rim, under the content.
struct SpotPictureStage<Content: View>: View {
    let size: CGSize
    let radius: CGFloat
    /// What places the wallpaper, such as the name of the picture.
    let seed: String
    let content: Content

    init(size: CGSize, radius: CGFloat, seed: String = "", @ViewBuilder content: () -> Content) {
        self.size = size
        self.radius = radius
        self.seed = seed
        self.content = content()
    }

    static var margin: CGFloat { 48 }
    private static var shade: Double { 0.28 }
    private static var blur: CGFloat { 40 }

    /// The wallpaper blurred into a picture, because a blur of a view does not show when the view is drawn to a picture.
    private var blurred: Image {
        let whole = CGSize(width: size.width + 2 * Self.margin, height: size.height + 2 * Self.margin)
        let renderer = ImageRenderer(content: SpotWallpaper(seed: seed).frame(width: whole.width, height: whole.height).blur(radius: Self.blur, opaque: true))
        renderer.scale = 2
        return renderer.cgImage.map { Image(decorative: $0, scale: 2) } ?? Image(systemName: "square")
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            SpotWallpaper(seed: seed)
            blurred
                .overlay(Color.black.opacity(Self.shade))
                .overlay(SpotTheme.glass)
                .mask { shape.frame(width: size.width, height: size.height) }
            content
                .frame(width: size.width, height: size.height)
                .overlay { SpotRimPicture(size: size, radius: radius) }
        }
        .frame(width: size.width + 2 * Self.margin, height: size.height + 2 * Self.margin)
    }
}

/// A dark wallpaper of layered ridges with a violet light between them, which stands in for the desktop behind the panel.
/// The seed, such as the name of a picture, places the ridges and the light, so that each picture differs and stays the
/// same each time it is drawn.
struct SpotWallpaper: View {
    var seed = ""

    private static let sky = Color(red: 0.06, green: 0.10, blue: 0.27)
    private static let ground = Color(red: 0.00, green: 0.03, blue: 0.03)
    private static let light = Color(red: 0.62, green: 0.62, blue: 1.00)
    private static let ridges = 6

    var body: some View {
        Canvas { context, size in
            var random = Seed(seed)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Self.sky, Self.ground]),
                startPoint: CGPoint(x: size.width * 0.2, y: 0),
                endPoint: CGPoint(x: size.width * 0.6, y: size.height)
            ))
            let glow = CGPoint(x: size.width * random.next(0.35, 0.65), y: size.height * random.next(0.45, 0.70))
            let reach = max(size.width, size.height) * random.next(0.45, 0.6)
            let tilt = Angle.degrees(random.next(-65, -45))
            for index in 0..<Self.ridges {
                let depth = Double(index + 1) / Double(Self.ridges)
                let fromLeft = index.isMultiple(of: 2)
                let start = size.height * (0.1 + 0.5 * depth) + size.height * random.next(-0.08, 0.08)
                let slope = size.height * random.next(0.25, 0.55) * (fromLeft ? 1 : -1)
                let wave = size.height * random.next(0.02, 0.06)
                let phase = random.next(0, 6.28)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height))
                let steps = 48
                for step in 0...steps {
                    let x = Double(step) / Double(steps)
                    let y = start + slope * (fromLeft ? x : x - 1) + wave * sin(phase + x * 5) + wave * 0.4 * sin(phase * 2 + x * 13)
                    path.addLine(to: CGPoint(x: x * size.width, y: y))
                }
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.closeSubpath()
                let shade = Color(red: 0.01 * (1 - depth), green: 0.04 + 0.08 * (1 - depth), blue: 0.06 + 0.16 * (1 - depth))
                var layer = context
                layer.addFilter(.shadow(color: Self.light.opacity(0.35 * (1 - depth)), radius: 18))
                layer.fill(path, with: .linearGradient(
                    Gradient(colors: [shade, Self.ground]),
                    startPoint: CGPoint(x: glow.x, y: start),
                    endPoint: CGPoint(x: fromLeft ? 0 : size.width, y: size.height)
                ))
            }
            var streak = context
            streak.blendMode = .screen
            streak.translateBy(x: glow.x, y: glow.y)
            streak.rotate(by: tilt)
            streak.scaleBy(x: 1, y: 0.28)
            streak.fill(Path(ellipseIn: CGRect(x: -reach, y: -reach, width: 2 * reach, height: 2 * reach)), with: .radialGradient(
                Gradient(colors: [Self.light.opacity(0.9), Self.light.opacity(0.3), .clear]),
                center: .zero,
                startRadius: 0,
                endRadius: reach
            ))
        }
    }
}

/// A small generator of numbers from a text, the same numbers for the same text.
private struct Seed {
    private var state: UInt64

    init(_ text: String) {
        state = text.utf8.reduce(1_469_598_103_934_665_603) { ($0 ^ UInt64($1)) &* 1_099_511_628_211 }
    }

    /// The next number between the two bounds.
    mutating func next(_ low: Double, _ high: Double) -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return low + (high - low) * Double(state >> 11) / Double(1 << 53)
    }
}
