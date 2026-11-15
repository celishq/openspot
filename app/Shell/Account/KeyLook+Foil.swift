import OpenspotCore
import SwiftUI

extension KeyLook {
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
}
