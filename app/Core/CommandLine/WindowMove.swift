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
            x: edge(target.minX, target.maxX, length: size.width, area: (area.minX, area.maxX)),
            y: edge(target.minY, target.maxY, length: size.height, area: (area.minY, area.maxY))
        )
    }

    /// The place a window takes before it gets this size, as an app cuts a size that would leave its screen. It is
    /// the window's own place when the size fits from there, else the nearest place on its own screen, or on the
    /// screen of its target when its own screen is too small.
    public static func start(of size: CGSize, from origin: CGPoint, home: CGRect, area: CGRect) -> CGPoint {
        let room = size.width <= home.width && size.height <= home.height ? home : area
        return CGPoint(
            x: max(room.minX, min(origin.x, room.maxX - size.width)),
            y: max(room.minY, min(origin.y, room.maxY - size.height))
        )
    }

    /// The size a window takes for a wanted size, given the size it has and a way to ask the app for a size, which
    /// returns the size the app then gives. An app that refuses a size under its own smallest keeps its old size, so
    /// an axis that is longer than wanted is asked again from the wanted length upward until the app takes it, and
    /// the other axis keeps its wanted length. A refused size shows nothing, so the window changes once, or twice
    /// when both axes are under the smallest.
    public static func fit(_ wanted: CGSize, from old: CGSize, ask: (CGSize) -> CGSize) -> CGSize {
        func near(_ first: CGFloat, _ second: CGFloat) -> Bool { abs(first - second) <= 1 }
        let size = ask(wanted)
        let longWidth = size.width > wanted.width + 1
        let longHeight = size.height > wanted.height + 1
        guard near(size.width, old.width), near(size.height, old.height), longWidth || longHeight else { return size }
        func takes(_ width: CGFloat, _ height: CGFloat) -> Bool {
            let given = ask(CGSize(width: width, height: height))
            return near(given.width, width) && near(given.height, height)
        }
        if longWidth, let width = rise(wanted.width, to: size.width, taken: { takes($0, wanted.height) }) {
            return CGSize(width: width, height: wanted.height)
        }
        if longHeight, let height = rise(wanted.height, to: size.height, taken: { takes(wanted.width, $0) }) {
            return CGSize(width: wanted.width, height: height)
        }
        guard longWidth, longHeight else { return ask(size) }
        let width = rise(wanted.width, to: size.width) { takes($0, size.height) } ?? size.width
        let height = rise(wanted.height, to: size.height) { takes(width, $0) } ?? size.height
        return ask(CGSize(width: width, height: height))
    }

    /// The first length from `low` upward to `high`, by small steps, that is `taken`, or nil.
    private static func rise(_ low: CGFloat, to high: CGFloat, taken: (CGFloat) -> Bool) -> CGFloat? {
        let step = max(4, ((high - low) / 100).rounded(.up))
        var length = low
        while length < high {
            if taken(length) { return length }
            length += step
        }
        return taken(high) ? high : nil
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

    private static func edge(_ low: CGFloat, _ high: CGFloat, length: CGFloat, area: (CGFloat, CGFloat)) -> CGFloat {
        let holdsLow = (low + high) / 2 <= (area.0 + area.1) / 2 + 1
        let fits = holdsLow ? low + length <= area.1 : high - length >= area.0
        let begin = holdsLow == fits ? low : high - length
        return max(area.0, min(begin, area.1 - length))
    }
}
