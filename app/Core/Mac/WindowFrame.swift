import Foundation

public struct WindowFrame: Equatable, Sendable {
    public let window: CGRect
    public let area: CGRect

    public init(window: CGRect, area: CGRect) {
        self.window = window
        self.area = area
    }

    var text: String {
        [window.minX, window.minY, window.width, window.height, area.minX, area.minY, area.width, area.height]
            .map { String(Int($0.rounded())) }.joined(separator: " ") + "\n"
    }
}
