import Foundation

public struct ToastLayout: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let offset: CGFloat
        public let scale: CGFloat
        public let showsContent: Bool
        public let edge: CGFloat?
    }

    public let places: [Place]
    public let height: CGFloat

    public init(heights: [CGFloat], isExpanded: Bool) {
        var places: [Place] = []
        var top: CGFloat = 0
        let front = heights.first ?? 0
        for (index, height) in heights.enumerated() {
            let edge = index == 0 ? nil : places[index - 1].offset + heights[index - 1]
            if isExpanded {
                places.append(Place(offset: top, scale: 1, showsContent: true, edge: edge))
                top += height + SpotTokens.toastStackGap
            } else {
                let depth = CGFloat(index)
                let offset = max(front + depth * SpotTokens.toastPeek - height, 0)
                places.append(Place(offset: offset, scale: 1 - depth * SpotTokens.toastDepthScale, showsContent: index == 0, edge: edge))
            }
        }
        self.places = places
        height = zip(places, heights).map { $0.offset + $1 }.max() ?? 0
    }
}
