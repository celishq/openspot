import OpenspotCore
import SwiftUI

struct SpotSurface: View {
    let rect: CGRect
    let radius: CGFloat
    var glass = 1.0
    var marks: [FlowEdge] = []
    var markRoom: CGRect = .zero
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotGrid) private var grid
    @Environment(\.spotFade) private var fade

    var body: some View {
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                Color.clear
                    .spotGlass(in: SpotSurfaceShape(rect: place(of: mark), radius: mark.radius))
                    .opacity(isShown ? strength(of: mark) : MotionTokens.hiddenOpacity)
                    .transition(.opacity)
            }
            Color.clear
                .spotGlass(in: shape)
                .opacity(isShown ? max(glass, MotionTokens.hiddenOpacity) * SpotTheme.glassStrength(at: fade) : MotionTokens.hiddenOpacity)
                .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        }
        .modifier(PanelSpan(grid: grid))
        .allowsHitTesting(false)
    }

    private func place(of mark: FlowEdge) -> CGRect {
        mark.rect(around: markRoom)
    }

    private func strength(of mark: FlowEdge) -> Double {
        guard !mark.isFading else { return MotionTokens.hiddenOpacity }
        guard case .bar(_, let index) = mark.place else { return 1 }
        let strengths = SpotTheme.edgeStrengths
        return strengths[min(index, strengths.count - 1)]
    }
}
