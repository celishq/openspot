import SwiftUI

struct FoilLook {
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
        var random = KeySeed(key)
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
        var seeds = KeySeed(key + "seed")
        seed = SIMD3(Float(seeds.next()), Float(seeds.next()), Float(seeds.next()))
        emblem = Self.dots(of: key)
    }

    var engrave: Color {
        isDark ? Color(red: 236 / 255, green: 238 / 255, blue: 244 / 255).opacity(0.9) : Color(red: 18 / 255, green: 20 / 255, blue: 26 / 255).opacity(0.8)
    }

    var catchLight: Color {
        isDark ? .black.opacity(0.6) : .white.opacity(0.55)
    }

    func shader(size: CGSize, tilt: CGPoint) -> Shader {
        ShaderLibrary.default.foil(
            .float2(size), .float2(tilt), .float3(seed.x, seed.y, seed.z),
            .float3(stops[0].x, stops[0].y, stops[0].z), .float3(stops[1].x, stops[1].y, stops[1].z), .float3(stops[2].x, stops[2].y, stops[2].z),
            .float(angle), .float2(center), .float(shape), .float(pattern), .float(facets), .float(freq)
        )
    }

    private static func dots(of key: String) -> [CGRect] {
        var random = KeySeed(key + "emblem")
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
