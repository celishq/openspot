import OpenspotCore
import SwiftUI

struct SpotSurface: View {
    let rect: CGRect
    let radius: CGFloat
    var glass = 1.0
    var marks: [FlowEdge] = []
    var markRoom: CGRect = .zero
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotPanels) private var panels

    var body: some View {
        let rect = rect.offsetBy(dx: -panels.frame.minX, dy: 0)
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                Color.clear
                    .glassEffect(.regular, in: SpotSurfaceShape(rect: place(of: mark), radius: mark.radius))
                    .opacity(isShown ? strength(of: mark) : MotionTokens.hiddenOpacity)
                    .transition(.opacity)
            }
            Color.clear
                .glassEffect(.regular, in: shape)
                .opacity(isShown ? glass : MotionTokens.hiddenOpacity)
                .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        }
        .modifier(PanelSpan(panels: panels))
        .allowsHitTesting(false)
    }

    private func place(of mark: FlowEdge) -> CGRect {
        mark.rect(around: markRoom).offsetBy(dx: -panels.frame.minX, dy: 0)
    }

    private func strength(of mark: FlowEdge) -> Double {
        guard !mark.isFading else { return MotionTokens.hiddenOpacity }
        guard case .bar(_, let index) = mark.place else { return glass }
        return SpotTheme.edgeStrengths[min(index, SpotTheme.edgeStrengths.count - 1)]
    }
}
