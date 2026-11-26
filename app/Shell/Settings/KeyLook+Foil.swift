import OpenspotCore
import SwiftUI

extension KeyLook {
    @MainActor var engrave: Color {
        isDark ? SpotTheme.engraveDark : SpotTheme.engraveLight
    }

    @MainActor var inverse: Color {
        isDark ? SpotTheme.engraveLight : SpotTheme.engraveDark
    }

    @MainActor var catchLight: Color {
        isDark ? SpotTheme.catchLightDark : SpotTheme.catchLightLight
    }

    func shader(size: CGSize, tilt: CGPoint) -> Shader {
        ShaderLibrary.default.foil(
            .float2(size), .float2(tilt), .float3(seed.x, seed.y, seed.z),
            .float3(stops[0].x, stops[0].y, stops[0].z), .float3(stops[1].x, stops[1].y, stops[1].z), .float3(stops[2].x, stops[2].y, stops[2].z),
            .float(angle), .float2(center), .float(shape), .float(pattern), .float(facets), .float(freq)
        )
    }
}
