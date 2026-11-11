import Foundation

/// The frames that `openspot window move` takes, each as x y width height.
/// A percent, a fraction or a plain number from 0 to 1 is a part of the usable area of the screen, and any other number is points.
/// With more than one frame, the window moves to the frame after the one it holds now, or to the first.
public struct WindowMove: Equatable, Sendable {
    private struct Value: Equatable, Sendable {
        let number: CGFloat
        let isPart: Bool
    }

    private static let margin: CGFloat = 20
    private let frames: [[Value]]

    /// Reads groups of four values from the words, which may each hold several values. Returns nil for anything else.
    public init?(words: [String]) {
        let values = words.flatMap { $0.split(separator: " ").map(String.init) }
        guard !values.isEmpty, values.count.isMultiple(of: 4) else { return nil }
        var frames: [[Value]] = []
        for start in stride(from: 0, to: values.count, by: 4) {
            let frame = values[start..<start + 4].compactMap(Self.value)
            guard frame.count == 4, frame[2].number > 0, frame[3].number > 0 else { return nil }
            frames.append(frame)
        }
        self.frames = frames
    }

    /// True when a frame is in parts of the area, so the caller must find the area.
    public var needsArea: Bool { frames.joined().contains(where: \.isPart) }

    /// The frame for a window that is at this frame now, inside this area.
    public func target(window: CGRect, area: CGRect) -> CGRect {
        let rects = frames.map { Self.rect($0, in: area) }
        guard rects.count > 1, let held = rects.firstIndex(where: { Self.near($0, window) }) else { return rects[0] }
        return rects[(held + 1) % rects.count]
    }

    /// The top left corner for a window of this real size in its target. On each axis it holds the target's edge in
    /// the half of the area that holds the target, the top or the left one for a target in the middle, to a point. A
    /// window that would leave the area from that edge holds the other edge, and it stays inside the area.
    public static func origin(of size: CGSize, target: CGRect, area: CGRect) -> CGPoint {
        CGPoint(
            x: start(target.minX, target.maxX, length: size.width, area: (area.minX, area.maxX)),
            y: start(target.minY, target.maxY, length: size.height, area: (area.minY, area.maxY))
        )
    }

    /// The size a window takes for a wanted size, given the size it has and a way to ask the app for a size, which
    /// returns the size the app then gives. An app that refuses a whole size smaller than its own smallest keeps its
    /// old size, so each axis it kept is asked again from the wanted length upward, with the other axis wanted, until
    /// the app takes it. A refused size shows nothing, so the window changes once.
    public static func fit(_ wanted: CGSize, from old: CGSize, ask: (CGSize) -> CGSize) -> CGSize {
        var size = ask(wanted)
        func near(_ first: CGFloat, _ second: CGFloat) -> Bool { abs(first - second) <= 1 }
        guard !near(size.width, wanted.width) || !near(size.height, wanted.height) else { return size }
        let keptWidth = wanted.width < old.width && near(size.width, old.width)
        let keptHeight = wanted.height < old.height && near(size.height, old.height)
        var asked = wanted
        if keptWidth { asked.width = rise(wanted.width, to: old.width) { ask(CGSize(width: $0, height: asked.height)).width } }
        if keptHeight { asked.height = rise(wanted.height, to: old.height) { ask(CGSize(width: asked.width, height: $0)).height } }
        if keptWidth || keptHeight { size = CGSize(width: asked.width, height: asked.height) }
        return size
    }

    /// The first length from `low` upward, by small steps, that `taken` gives back, or `high`.
    private static func rise(_ low: CGFloat, to high: CGFloat, taken: (CGFloat) -> CGFloat) -> CGFloat {
        let step = max(4, ((high - low) / 100).rounded(.up))
        var length = low + step
        while length < high {
            if abs(taken(length) - length) <= 1 { return length }
            length += step
        }
        _ = taken(high)
        return high
    }

    private static func value(_ word: String) -> Value? {
        if word.hasSuffix("%") { return Double(word.dropLast()).map { Value(number: CGFloat($0) / 100, isPart: true) } }
        let parts = word.split(separator: "/", omittingEmptySubsequences: false)
        if parts.count == 1 { return Double(word).map { Value(number: CGFloat($0), isPart: (0...1).contains($0)) } }
        guard parts.count == 2, let top = Double(parts[0]), let bottom = Double(parts[1]), bottom != 0 else { return nil }
        return Value(number: CGFloat(top / bottom), isPart: true)
    }

    private static func rect(_ frame: [Value], in area: CGRect) -> CGRect {
        let (x, width) = span(frame[0], frame[2], area.minX, area.width)
        let (y, height) = span(frame[1], frame[3], area.minY, area.height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// The start and the length on one axis, with whole-point edges so that parts side by side leave no gap.
    private static func span(_ start: Value, _ length: Value, _ low: CGFloat, _ size: CGFloat) -> (CGFloat, CGFloat) {
        let begin = start.isPart ? low + (size * start.number).rounded() : start.number
        if start.isPart && length.isPart { return (begin, low + (size * (start.number + length.number)).rounded() - begin) }
        return (begin, length.isPart ? (size * length.number).rounded() : length.number)
    }

    private static func near(_ first: CGRect, _ second: CGRect) -> Bool {
        abs(first.minX - second.minX) <= margin && abs(first.minY - second.minY) <= margin
            && abs(first.width - second.width) <= margin && abs(first.height - second.height) <= margin
    }

    private static func start(_ low: CGFloat, _ high: CGFloat, length: CGFloat, area: (CGFloat, CGFloat)) -> CGFloat {
        let holdsLow = (low + high) / 2 <= (area.0 + area.1) / 2 + 1
        let fits = holdsLow ? low + length <= area.1 : high - length >= area.0
        let begin = holdsLow == fits ? low : high - length
        return max(area.0, min(begin, area.1 - length))
    }
}
