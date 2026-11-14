import OpenspotCore
import SwiftUI

struct FlowLine: ViewModifier, @preconcurrency Animatable {
    var progress: Double
    let line: CGRect
    let sheet: CGRect
    var fadeStart = 0.0

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = CGFloat(progress)
        let place = CGRect(
            x: line.minX + (sheet.minX - line.minX) * t,
            y: line.minY + (sheet.minY - line.minY) * t,
            width: line.width + (sheet.width - line.width) * t,
            height: line.height + (sheet.height - line.height) * t
        )
        let scaleX = place.width / max(sheet.width, 1)
        let scaleY = place.height / max(sheet.height, 1)
        content
            .scaleEffect(x: scaleX, y: scaleY, anchor: .topLeading)
            .offset(x: place.minX - scaleX * sheet.minX, y: place.minY - scaleY * sheet.minY)
            .opacity(max((progress - fadeStart) / (1 - fadeStart), MotionTokens.hiddenOpacity))
    }
}
