import OpenspotCore
import SwiftUI

struct SpotFlowEdges: View {
    let model: SpotsModel
    let rect: CGRect
    @State private var resting: Int?
    @State private var named: Int?
    @State private var pause: Task<Void, Never>?

    var body: some View {
        let titles = model.behindTitles
        ZStack(alignment: .topLeading) {
            ForEach(Array(titles.prefix(SpotTokens.edgeCount).enumerated()), id: \.offset) { index, _ in
                edge(index)
            }
            if let named, titles.indices.contains(named) {
                tip(titles[named], over: named)
            }
        }
        .onChange(of: titles) { _, _ in
            resting = nil
            named = nil
        }
    }

    private func edgeX(_ index: Int) -> CGFloat {
        rect.minX - SpotTokens.edgeGap - SpotTokens.edgeWidth - CGFloat(index) * (SpotTokens.edgeWidth + SpotTokens.edgeStep)
    }

    private func edge(_ index: Int) -> some View {
        let height = max(rect.height - 2 * SpotTokens.radius - CGFloat(index) * SpotTokens.edgeShrink, SpotTokens.edgeWidth)
        return Color.clear
            .frame(width: SpotTokens.edgeWidth, height: height)
            .modifier(SpotGlass(radius: SpotTokens.edgeWidth / 2))
            .opacity(SpotTheme.edgeStrengths[index])
            .padding(.horizontal, SpotTokens.edgeStep / 2)
            .contentShape(Rectangle())
            .onHover { inside in hover(index, inside) }
            .onTapGesture { model.back(steps: index + 1) }
            .offset(x: edgeX(index) - SpotTokens.edgeStep / 2, y: rect.midY - height / 2)
    }

    private func tip(_ title: String, over index: Int) -> some View {
        Text(title)
            .font(SpotType.detail)
            .foregroundStyle(SpotTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, SpotTokens.hintEndPadding)
            .frame(height: SpotTokens.hintPillHeight)
            .modifier(SpotGlass(radius: SpotTokens.hintPillHeight / 2))
            .fixedSize()
            .offset(x: edgeX(index) - SpotTokens.hintEndPadding, y: rect.minY - SpotTokens.hintPillHeight - SpotTokens.placeGap)
            .allowsHitTesting(false)
    }

    private func hover(_ index: Int, _ inside: Bool) {
        pause?.cancel()
        guard inside else {
            if resting == index { resting = nil; named = nil }
            return
        }
        resting = index
        pause = Task { @MainActor in
            try? await Task.sleep(for: SpotTokens.edgeRest)
            guard !Task.isCancelled, resting == index else { return }
            named = index
        }
    }
}
