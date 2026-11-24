import Foundation

public struct ToastLayout: Equatable, Sendable {
    public struct Place: Equatable, Sendable {
        public let offset: CGFloat
        public let scale: CGFloat
        public let showsContent: Bool
    }

    public let places: [Place]
    public let height: CGFloat

    public init(heights: [CGFloat], isExpanded: Bool) {
        var places: [Place] = []
        var top: CGFloat = 0
        let front = heights.first ?? 0
        for (index, height) in heights.enumerated() {
            if isExpanded {
                places.append(Place(offset: top, scale: 1, showsContent: true))
                top += height + SpotTokens.toastStackGap
            } else {
                let depth = CGFloat(index)
                places.append(Place(offset: max(front + depth * SpotTokens.toastPeek - height, 0), scale: 1 - depth * SpotTokens.toastDepthScale, showsContent: index == 0))
            }
        }
        self.places = places
        height = zip(places, heights).map { $0.offset + $1 }.max() ?? 0
    }
}
