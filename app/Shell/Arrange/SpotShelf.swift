import OpenspotCore
import SwiftUI

struct SpotShelf: View {
    let model: SpotsModel
    let layout: ShelfLayout

    var body: some View {
        let spots = model.shelf.spots
        let pitch = ShelfLayout.chunkPitch
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(layout.chunks.indices, id: \.self) { chunk in
                    ZStack(alignment: .topLeading) {
                        ForEach(cards(in: chunk, of: spots), id: \.id) { index, id in
                            let rect = layout.rects[index]
                            SpotCardView(entry: spots[index], size: layout.sizes[index], index: -1, isPressed: false, takesDrag: false, isDropTarget: false, model: model, onTap: {})
                                .equatable()
                                .modifier(ShelfCarry(model: model, id: id))
                                .offset(x: rect.minX, y: rect.minY - CGFloat(chunk) * pitch)
                                .gesture(drag(of: id))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: chunk == layout.chunks.count - 1 ? layout.height - CGFloat(chunk) * pitch : pitch, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .padding(.vertical, SpotTokens.scrollFadeLength)
        }
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in
            model.shelf.scrolled(to: offset)
        })
        .mask(ShelfFade(height: layout.band.upperBound - layout.band.lowerBound))
    }

    private func cards(in chunk: Int, of spots: [SpotsModel.Entry]) -> [(index: Int, id: String)] {
        layout.chunks[chunk].filter(spots.indices.contains).map { ($0, spots[$0].id) }
    }

    private func drag(of id: String) -> some Gesture {
        DragGesture(coordinateSpace: .named(SpotArrangeView.space))
            .onChanged { value in
                var still = Transaction()
                still.tracksVelocity = false
                withTransaction(still) { model.dragShelfSpot(id, by: value.translation) }
            }
            .onEnded { model.dropShelfSpot(by: $0.translation) }
    }
}

private struct ShelfCarry: ViewModifier {
    let model: SpotsModel
    let id: String

    func body(content: Content) -> some View {
        content.opacity(model.pin?.id == id || model.landing == id ? MotionTokens.hiddenOpacity : 1)
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
