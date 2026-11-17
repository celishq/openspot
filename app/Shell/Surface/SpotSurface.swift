import OpenspotCore
import SwiftUI

struct SpotSurface: View {
    let rect: CGRect
    let radius: CGFloat
    var glass = 1.0
    var marks: [FlowEdge] = []
    var markRoom: CGRect = .zero
    var cut: SpotSurfaceShape?
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotPanels) private var panels
    @Environment(\.spotFade) private var fade

    var body: some View {
        let rect = rect.offsetBy(dx: -panels.frame.minX, dy: 0)
        let shape = SpotSurfaceShape(rect: rect, radius: radius)
        ZStack(alignment: .topLeading) {
            ForEach(marks) { mark in
                Color.clear
                    .spotGlass(in: SpotSurfaceShape(rect: place(of: mark), radius: mark.radius))
                    .opacity(isShown ? strength(of: mark) : MotionTokens.hiddenOpacity)
                    .transition(.opacity)
            }
            Color.clear
                .spotGlass(in: SpotCutShape(shape: shape, cut: cutShape))
                .opacity(isShown ? max(glass, MotionTokens.hiddenOpacity) * SpotTheme.glassStrength(at: fade) : MotionTokens.hiddenOpacity)
                .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        }
        .modifier(PanelSpan(panels: panels))
        .allowsHitTesting(false)
    }

    private var cutShape: SpotSurfaceShape {
        guard var cut else { return SpotSurfaceShape(rect: .zero, radius: 0) }
        cut.rect = cut.rect.offsetBy(dx: -panels.frame.minX, dy: 0)
        return cut
    }

    private func place(of mark: FlowEdge) -> CGRect {
        mark.rect(around: markRoom).offsetBy(dx: -panels.frame.minX, dy: 0)
    }

    private func strength(of mark: FlowEdge) -> Double {
        guard !mark.isFading else { return MotionTokens.hiddenOpacity }
        guard case .bar(_, let index) = mark.place else { return glass }
        let strengths = SpotTheme.edgeStrengths
        return strengths[min(index, strengths.count - 1)]
    }
}
