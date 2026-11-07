import Foundation

/// The frames that `openspot window move` takes, each as x y width height.
/// A frame with a fraction, such as 1/2, is in parts of the usable area of the screen, and any other frame is in points.
/// With more than one frame, the window moves to the frame after the one it holds now, or to the first.
public struct WindowMove: Equatable, Sendable {
    private struct Frame: Equatable, Sendable {
        let values: [Double]
        let inParts: Bool
    }

    private static let margin: CGFloat = 20
    private let frames: [Frame]

    /// Reads groups of four values from the words, which may each hold several values. Returns nil for anything else.
    public init?(words: [String]) {
        let values = words.flatMap { $0.split(separator: " ").map(String.init) }
        guard !values.isEmpty, values.count.isMultiple(of: 4) else { return nil }
        var frames: [Frame] = []
        for start in stride(from: 0, to: values.count, by: 4) {
            let group = values[start..<start + 4]
            let numbers = group.compactMap(Self.number)
            guard numbers.count == 4, numbers[2] > 0, numbers[3] > 0 else { return nil }
            frames.append(Frame(values: numbers, inParts: group.contains { $0.contains("/") }))
        }
        self.frames = frames
    }

    /// True when a frame is in parts of the area, so the caller must find the area.
    public var needsArea: Bool { frames.contains(where: \.inParts) }

    /// The frame for a window that is at this frame now, inside this area.
    public func target(window: CGRect, area: CGRect) -> CGRect {
        let rects = frames.map { Self.rect($0, in: area) }
        guard rects.count > 1, let held = rects.firstIndex(where: { Self.near($0, window) }) else { return rects[0] }
        return rects[(held + 1) % rects.count]
    }

    /// The top left corner for a window of this real size, which holds each edge of the area that the target touches.
    public static func origin(of size: CGSize, target: CGRect, area: CGRect) -> CGPoint {
        CGPoint(
            x: start(target.minX, target.maxX, area.minX, area.maxX, size.width),
            y: start(target.minY, target.maxY, area.minY, area.maxY, size.height)
        )
    }

    private static func number(_ word: String) -> Double? {
        let parts = word.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 1 { return Double(word) }
        guard parts.count == 2, let top = Double(parts[0]), let bottom = Double(parts[1]), bottom != 0 else { return nil }
        return top / bottom
    }

    private static func rect(_ frame: Frame, in area: CGRect) -> CGRect {
        let v = frame.values.map { CGFloat($0) }
        guard frame.inParts else { return CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }
        let left = (area.width * v[0]).rounded(), right = (area.width * (v[0] + v[2])).rounded()
        let top = (area.height * v[1]).rounded(), bottom = (area.height * (v[1] + v[3])).rounded()
        return CGRect(x: area.minX + left, y: area.minY + top, width: right - left, height: bottom - top)
    }

    private static func near(_ first: CGRect, _ second: CGRect) -> Bool {
        abs(first.minX - second.minX) <= margin && abs(first.minY - second.minY) <= margin
            && abs(first.width - second.width) <= margin && abs(first.height - second.height) <= margin
    }

    private static func start(_ low: CGFloat, _ high: CGFloat, _ areaLow: CGFloat, _ areaHigh: CGFloat, _ length: CGFloat) -> CGFloat {
        if abs(low - areaLow) < 1 { return low }
        if abs(high - areaHigh) < 1 { return high - length }
        return (low + (high - low - length) / 2).rounded()
    }
}
