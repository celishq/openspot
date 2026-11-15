import SwiftUI

/// The publisher card: a foil whose colours, shape, lines, grain and emblem come from the public key, with the name, the
/// month the key was made and the short key. It tilts toward the pointer, and sways slowly while the pointer is away.
struct SpotView: View {
    let spot: SpotInput
    @State private var pointer: CGPoint?
    @State private var tilt = Tilt()

    var body: some View {
        let look = Look(key: spot["npub"] ?? "")
        let size = Self.fit(in: spot.size)
        TimelineView(.animation) { context in
            card(look, size: size, tilt: tilt.next(toward: pointer, at: context.date.timeIntervalSinceReferenceDate))
        }
        .frame(width: spot.size.width, height: spot.size.height)
    }

    /// The largest card of the shape of a bank card that fits the place.
    static func fit(in place: CGSize) -> CGSize {
        let ratio = 263.0 / 166.0
        let width = min(place.width, place.height * ratio)
        return CGSize(width: width, height: width / ratio)
    }

    private func card(_ look: Look, size: CGSize, tilt: CGPoint) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return ZStack {
            Rectangle().fill(.white).colorEffect(look.shader(size: size, tilt: tilt))
            face(look, tilt: tilt)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .onContinuousHover { phase in
            switch phase {
            case .active(let at): pointer = CGPoint(x: at.x / size.width * 2 - 1, y: at.y / size.height * 2 - 1)
            case .ended: pointer = nil
            }
        }
        .rotation3DEffect(.degrees(tilt.x * 12), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .rotation3DEffect(.degrees(-tilt.y * 9), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
        .shadow(color: .black.opacity(0.5), radius: 12, x: -tilt.x * 8, y: 8 - tilt.y * 6)
    }

    private func face(_ look: Look, tilt: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            top(look)
            Spacer(minLength: 0)
            if let name = spot["name"] {
                Text(name).font(.system(size: 24, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            bottom.padding(.top, 8)
        }
        .padding(16)
        .foregroundStyle(look.engrave)
        .shadow(color: look.catchLight, radius: 0, x: -tilt.x * 0.8, y: 1 - tilt.y * 0.8)
    }

    private func top(_ look: Look) -> some View {
        HStack(alignment: .top) {
            Text("OPENSPOT PUBLISHER").font(.system(size: 9.5, weight: .bold)).tracking(1.9)
            Spacer()
            Emblem(dots: look.emblem).fill(look.engrave).frame(width: 26, height: 26)
        }
    }

    private var bottom: some View {
        HStack(alignment: .bottom) {
            if let since = spot["since"] { Text("Since \(since)").font(.system(size: 10.5, weight: .medium)) }
            Spacer(minLength: 8)
            Text(spot["short"] ?? "").font(.system(size: 10.5, weight: .medium, design: .monospaced))
        }
    }
}

/// The tilt of the card, which eases toward the pointer, or toward a slow sway while the pointer is away.
final class Tilt {
    private var now = CGPoint.zero

    /// The tilt of the next frame, from -1 to 1 on each axis.
    func next(toward pointer: CGPoint?, at time: Double) -> CGPoint {
        let goal = pointer ?? CGPoint(x: sin(time * 0.6) * 0.5, y: sin(time * 0.45) * 0.35)
        let rate = pointer == nil ? 0.05 : 0.18
        now = CGPoint(x: now.x + (goal.x - now.x) * rate, y: now.y + (goal.y - now.y) * rate)
        return now
    }
}

/// The mirrored dots of the emblem, in a box of 26 points.
struct Emblem: Shape {
    let dots: [CGRect]

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / 26
        var path = Path()
        for dot in dots {
            path.addEllipse(in: CGRect(x: rect.minX + dot.minX * scale, y: rect.minY + dot.minY * scale, width: dot.width * scale, height: dot.height * scale))
        }
        return path
    }
}

/// The look a public key gives its card. The same key gives the same look in the app and in the mock-up.
struct Look {
    let stops: [SIMD3<Float>]
    let angle: Float
    let center: CGPoint
    let shape: Float
    let pattern: Float
    let facets: Float
    let freq: Float
    let seed: SIMD3<Float>
    let emblem: [CGRect]
    let isDark: Bool

    init(key: String) {
        var random = Random(key)
        let roll = random.next()
        let scheme = roll < 0.3 ? 0 : roll < 0.52 ? 1 : roll < 0.72 ? 2 : roll < 0.9 ? 3 : 4
        let anchors: [Double] = [25, 55, 85, 120, 155, 190, 225, 260, 290, 325, 355]
        let night: [Double] = [190, 225, 260, 290, 325, 355]
        let hue = (scheme == 4 ? night[random.pick(night.count)] : anchors[random.pick(anchors.count)]) + (random.next() - 0.5) * 14
        let chroma = 0.11 + random.next() * 0.07
        var lch: [[Double]]
        switch scheme {
        case 0:
            let d = (random.next() < 0.5 ? 1.0 : -1.0) * (30 + random.next() * 30)
            lch = [[0.8, chroma, hue], [0.74, chroma, hue + d], [0.82, chroma * 0.9, hue + 2 * d]]
        case 1: lch = [[0.78, chroma, hue], [0.8, chroma * 0.7, hue + 90], [0.74, chroma, hue + 180]]
        case 2: lch = [[0.8, chroma, hue], [0.76, chroma, hue + 120], [0.8, chroma, hue + 240]]
        case 3: lch = [[0.92, chroma * 0.45, hue], [0.76, chroma, hue], [0.6, chroma * 1.1, hue + 6]]
        default:
            let d = 15 + random.next() * 20
            lch = [[0.36, chroma * 0.8, hue], [0.44, chroma, hue + d], [0.32, chroma * 0.8, hue - d]]
        }
        stops = lch.map { SIMD3(Float($0[0]), Float($0[1]), Float((($0[2].truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) * .pi / 180)) }
        isDark = scheme == 4
        angle = Float(random.next() * .pi * 2)
        center = CGPoint(x: 0.3 + random.next(), y: 0.2 + random.next() * 0.6)
        shape = Float(random.pick(5))
        pattern = Float(random.pick(5))
        facets = [70, 110, 160, 240][random.pick(4)]
        freq = Float(3 + random.next() * 9)
        var seeds = Random(key + "seed")
        seed = SIMD3(Float(seeds.next()), Float(seeds.next()), Float(seeds.next()))
        emblem = Self.dots(of: key)
    }

    var engrave: Color {
        isDark ? Color(red: 236 / 255, green: 238 / 255, blue: 244 / 255).opacity(0.9) : Color(red: 18 / 255, green: 20 / 255, blue: 26 / 255).opacity(0.8)
    }

    var catchLight: Color {
        isDark ? .black.opacity(0.6) : .white.opacity(0.55)
    }

    /// The foil shader of the app at this size and tilt.
    func shader(size: CGSize, tilt: CGPoint) -> Shader {
        ShaderLibrary.default.foil(
            .float2(size), .float2(tilt), .float3(seed.x, seed.y, seed.z),
            .float3(stops[0].x, stops[0].y, stops[0].z), .float3(stops[1].x, stops[1].y, stops[1].z), .float3(stops[2].x, stops[2].y, stops[2].z),
            .float(angle), .float2(center), .float(shape), .float(pattern), .float(facets), .float(freq)
        )
    }

    private static func dots(of key: String) -> [CGRect] {
        var random = Random(key + "emblem")
        let cell = 26.0 / 5, sizes = [0.18, 0.3, 0.42]
        var found: [CGRect] = []
        for y in 0..<5 {
            for x in 0..<3 {
                if random.next() < 0.38 { continue }
                let radius = cell * sizes[random.pick(sizes.count)]
                for column in Set([x, 4 - x]).sorted() {
                    found.append(CGRect(x: Double(column) * cell + cell / 2 - radius, y: Double(y) * cell + cell / 2 - radius, width: radius * 2, height: radius * 2))
                }
            }
        }
        return found.count < 6 ? dots(of: key + "+") : found
    }
}

/// Numbers from 0 to 1 that follow from a text, the same as the mock-up's.
struct Random {
    private var state: UInt32

    init(_ text: String) {
        var hash: UInt32 = 2_166_136_261
        for unit in text.utf16 {
            hash ^= UInt32(unit)
            hash = hash &* 16_777_619
        }
        state = hash
    }

    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return Double(state % 10_000) / 10_000
    }

    mutating func pick(_ count: Int) -> Int {
        Int(next() * Double(count))
    }
}
