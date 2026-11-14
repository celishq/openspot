import OpenspotCore
import SwiftUI

struct SpotFlowEdges: View {
    let model: SpotsModel
    let rect: CGRect
    @State private var resting: FlowSheet?
    @State private var named: FlowSheet?
    @State private var pause: Task<Void, Never>?
    @Environment(\.spotIsShown) private var isShown
    @Environment(\.spotPanels) private var panels

    var body: some View {
        let edges = model.flowEdges.edges
        ZStack(alignment: .topLeading) {
            glass(edges)
            ForEach(edges.filter { !$0.isFading && $0.place.side != nil }) { edge in
                target(edge)
            }
            if let edge = edges.first(where: { $0.sheet == named && !$0.isFading }) {
                tip(edge.title, at: edge.rect(around: rect))
            }
        }
        .onChange(of: model.flowEdges.shown) { _, _ in
            resting = nil
            named = nil
        }
    }

    private func glass(_ edges: [FlowEdge]) -> some View {
        let shift = -panels.frame.minX
        return ZStack(alignment: .topLeading) {
            SpotBlur(radius: SpotTheme.blur)
                .overlay(SpotTheme.glass)
                .mask {
                    ZStack(alignment: .topLeading) {
                        ForEach(edges) { edge in
                            SpotSurfaceShape(rect: edge.rect(around: rect).offsetBy(dx: shift, dy: 0), radius: edge.radius)
                                .fill(Color.black.opacity(strength(of: edge)))
                                .transition(.opacity)
                        }
                    }
                }
            ForEach(edges) { edge in
                SpotRim(radius: edge.radius, rect: edge.rect(around: rect).offsetBy(dx: shift, dy: 0))
                    .opacity(strength(of: edge))
                    .transition(.opacity)
            }
        }
        .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
        .animation(SpotMotion.fade(isShown: isShown), value: isShown)
        .modifier(PanelSpan(panels: panels))
        .allowsHitTesting(false)
    }

    private func strength(of edge: FlowEdge) -> Double {
        guard !edge.isFading else { return MotionTokens.hiddenOpacity }
        guard case .bar(_, let index) = edge.place else { return 1 }
        return SpotTheme.edgeStrengths[min(index, SpotTheme.edgeStrengths.count - 1)]
    }

    private func target(_ edge: FlowEdge) -> some View {
        let place = edge.rect(around: rect)
        return Color.clear
            .frame(width: place.width + SpotTokens.edgeStep, height: place.height)
            .contentShape(Rectangle())
            .onHover { inside in hover(edge.sheet, inside) }
            .onTapGesture { go(to: edge) }
            .offset(x: place.minX - SpotTokens.edgeStep / 2, y: place.minY)
    }

    private func go(to edge: FlowEdge) {
        switch edge.place {
        case .bar(.behind, let index): model.back(steps: index + 1)
        case .bar(.ahead, let index): model.forward(steps: index + 1)
        default: break
        }
    }

    private func tip(_ title: String, at place: CGRect) -> some View {
        Text(title)
            .font(SpotType.detail)
            .foregroundStyle(SpotTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, SpotTokens.hintEndPadding)
            .frame(height: SpotTokens.hintPillHeight)
            .modifier(SpotGlass(radius: SpotTokens.hintPillHeight / 2))
            .fixedSize()
            .offset(x: place.minX - SpotTokens.hintEndPadding, y: rect.minY - SpotTokens.hintPillHeight - SpotTokens.placeGap)
            .allowsHitTesting(false)
    }

    private func hover(_ sheet: FlowSheet, _ inside: Bool) {
        pause?.cancel()
        guard inside else {
            if resting == sheet { resting = nil; named = nil }
            return
        }
        resting = sheet
        pause = Task { @MainActor in
            try? await Task.sleep(for: SpotTokens.edgeRest)
            guard !Task.isCancelled, resting == sheet else { return }
            named = sheet
        }
    }
}
