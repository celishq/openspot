import OpenspotCore
import SwiftUI

struct SpotShelf: View {
    let model: SpotsModel
    let layout: ShelfLayout
    let panelOrigin: CGPoint

    var body: some View {
        let spots = model.shelf
        let pitch = SpotTokens.height(rows: 2) + SpotTokens.rowGap
        let chunks = Dictionary(grouping: spots.indices.filter { layout.rects.indices.contains($0) }) { Int(layout.rects[$0].minY / pitch) }
        let count = max(Int((layout.height / pitch).rounded(.up)), 1)
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { chunk in
                    ZStack(alignment: .topLeading) {
                        ForEach(chunks[chunk] ?? [], id: \.self) { index in
                            let id = spots[index].id
                            let rect = layout.rects[index]
                            SpotCardView(entry: spots[index], size: layout.sizes[index], index: -1, isPressed: false, takesDrag: false, isDropTarget: false, model: model, onTap: {})
                                .equatable()
                                .modifier(ShelfCarry(model: model, id: id))
                                .offset(x: rect.minX, y: rect.minY - CGFloat(chunk) * pitch)
                                .gesture(drag(of: id, at: rect))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: chunk == count - 1 ? layout.height - CGFloat(chunk) * pitch : pitch, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in
            model.shelfScrolled(to: offset)
        })
        .mask(ShelfFade(height: layout.band.upperBound - layout.band.lowerBound))
    }

    private func drag(of id: String, at rect: CGRect) -> some Gesture {
        DragGesture(coordinateSpace: .named(SpotArrangeView.space))
            .onChanged { value in
                let origin = CGPoint(x: rect.minX - panelOrigin.x, y: layout.band.lowerBound + rect.minY - model.arrangeScroll - panelOrigin.y)
                var still = Transaction()
                still.tracksVelocity = false
                withTransaction(still) { model.dragShelfSpot(id, from: origin, by: value.translation) }
            }
            .onEnded { model.dropShelfSpot(by: $0.translation) }
    }
}

private struct ShelfCarry: ViewModifier {
    let model: SpotsModel
    let id: String

    func body(content: Content) -> some View {
        content.opacity(model.pin?.id == id ? MotionTokens.hiddenOpacity : 1)
    }
}

private struct ShelfFade: View {
    let height: CGFloat

    var body: some View {
        let edge = min(SpotTokens.scrollFadeLength / max(height, 1), 0.5)
        LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: SpotTheme.mask, location: edge),
            .init(color: SpotTheme.mask, location: 1 - edge),
            .init(color: .clear, location: 1),
        ], startPoint: .top, endPoint: .bottom)
    }
}
