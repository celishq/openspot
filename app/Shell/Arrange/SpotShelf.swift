import OpenspotCore
import SwiftUI

struct SpotShelf: View {
    let model: SpotsModel
    let layout: ShelfLayout
    let panelOrigin: CGPoint

    var body: some View {
        let spots = model.shelf
        let rows = (0..<layout.rows(of: spots.count)).map { row in
            Array(spots.indices.clamped(to: (row * layout.perRow)..<((row + 1) * layout.perRow)))
        }
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: SpotTokens.shelfRowGap) {
                ForEach(rows, id: \.first) { row in
                    ZStack(alignment: .topLeading) {
                        ForEach(row, id: \.self) { index in
                            let id = spots[index].id
                            SpotShelfCard(entry: spots[index])
                                .equatable()
                                .modifier(ShelfCarry(model: model, id: id))
                                .offset(x: layout.x(of: index))
                                .gesture(drag(of: id))
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: SpotTokens.shelfCard.height, alignment: .topLeading)
                }
            }
            .padding(.vertical, SpotTokens.shelfRowGap)
        }
        .onScrollGeometryChange(for: CGFloat.self, of: { $0.contentOffset.y }, action: { _, offset in
            model.shelfScrolled(to: offset)
        })
        .mask(ShelfFade(height: layout.band.upperBound - layout.band.lowerBound))
    }

    private func drag(of id: String) -> some Gesture {
        DragGesture(coordinateSpace: .named(SpotArrangeView.space))
            .onChanged { value in
                let half = SpotTokens.cell / 2
                let origin = CGPoint(x: value.startLocation.x - panelOrigin.x - half, y: value.startLocation.y - panelOrigin.y - half)
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
