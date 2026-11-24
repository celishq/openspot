import Foundation

public struct ToastLayout: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let offset: CGFloat
        public let scale: CGFloat
        public let showsContent: Bool
        public let cut: CGFloat
    }

    public let places: [Place]
    public let height: CGFloat

    public init(heights: [CGFloat], isExpanded: Bool) {
        var places: [Place] = []
        var top: CGFloat = 0
        let front = heights.first ?? 0
        for (index, height) in heights.enumerated() {
            if isExpanded {
                places.append(Place(offset: top, scale: 1, showsContent: true, cut: 0))
                top += height + SpotTokens.toastStackGap
            } else {
                let depth = CGFloat(index)
                let offset = max(front + depth * SpotTokens.toastPeek - height, 0)
                let scale = 1 - depth * SpotTokens.toastDepthScale
                let edge = index == 0 ? 0 : front + (depth - 1) * SpotTokens.toastPeek
                let top = offset + height * (1 - scale)
                places.append(Place(offset: offset, scale: scale, showsContent: index == 0, cut: max(edge - top, 0) / scale))
            }
        }
        self.places = places
        height = zip(places, heights).map { $0.offset + $1 }.max() ?? 0
    }
}
