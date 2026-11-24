import Foundation

public struct ToastLayout: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let offset: CGFloat
        public let scale: CGFloat
        public let showsContent: Bool
        public let cover: Cover
    }

    public struct Cover: Equatable, Sendable {
        public let offset: CGFloat
        public let height: CGFloat
        public let scale: CGFloat
    }

    public let places: [Place]
    public let height: CGFloat

    public init(heights: [CGFloat], isExpanded: Bool) {
        var places: [Place] = []
        var top: CGFloat = 0
        let front = heights.first ?? 0
        for (index, height) in heights.enumerated() {
            let cover = index == 0 ? Cover(offset: 0, height: 0, scale: 1) : Cover(offset: places[index - 1].offset, height: heights[index - 1], scale: places[index - 1].scale)
            if isExpanded {
                places.append(Place(offset: top, scale: 1, showsContent: true, cover: cover))
                top += height + SpotTokens.toastStackGap
            } else {
                let depth = CGFloat(index)
                let offset = max(front + depth * SpotTokens.toastPeek - height, 0)
                places.append(Place(offset: offset, scale: 1 - depth * SpotTokens.toastDepthScale, showsContent: index == 0, cover: cover))
            }
        }
        self.places = places
        height = zip(places, heights).map { $0.offset + $1 }.max() ?? 0
    }
}
