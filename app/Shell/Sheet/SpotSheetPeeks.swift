import OpenspotCore
import SwiftUI

/// The edges of the sheets behind the open one, stacked on its left, the nearest first and tallest: one for each sheet
/// behind, three at most. A pointer that rests on an edge names its sheet over the panel, and a click goes back to it. It
/// alone reads the titles of the sheets behind.
struct SpotSheetPeeks: View {
    let model: SpotsModel
    let rect: CGRect
    @State private var resting: Int?
    @State private var named: Int?
    @State private var pause: Task<Void, Never>?

    var body: some View {
        let titles = model.behindTitles
        ZStack(alignment: .topLeading) {
            ForEach(Array(titles.prefix(SpotTokens.peekCount).enumerated()), id: \.offset) { index, _ in
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
        rect.minX - SpotTokens.peekGap - SpotTokens.peekWidth - CGFloat(index) * (SpotTokens.peekWidth + SpotTokens.peekStep)
    }

    private func edge(_ index: Int) -> some View {
        let height = max(rect.height - 2 * SpotTokens.radius - CGFloat(index) * SpotTokens.peekShrink, SpotTokens.peekWidth)
        return Color.clear
            .frame(width: SpotTokens.peekWidth, height: height)
            .modifier(SpotGlass(radius: SpotTokens.peekWidth / 2))
            .opacity(SpotTheme.peekStrengths[index])
            .padding(.horizontal, SpotTokens.peekStep / 2)
            .contentShape(Rectangle())
            .onHover { inside in hover(index, inside) }
            .onTapGesture { model.goBack(steps: index + 1) }
            .offset(x: edgeX(index) - SpotTokens.peekStep / 2, y: rect.midY - height / 2)
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

    /// Names the sheet of an edge once the pointer has rested on it for a moment, so that a pointer that only crosses the
    /// edges names nothing.
    private func hover(_ index: Int, _ inside: Bool) {
        pause?.cancel()
        guard inside else {
            if resting == index { resting = nil; named = nil }
            return
        }
        resting = index
        pause = Task { @MainActor in
            try? await Task.sleep(for: SpotTokens.peekRest)
            guard !Task.isCancelled, resting == index else { return }
            named = index
        }
    }
}
