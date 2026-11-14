import Foundation

public struct WindowMove: Equatable, Sendable {
    private struct Value: Equatable, Sendable {
        let number: CGFloat
        let isPart: Bool
    }

    private static let margin: CGFloat = 20
    private let frames: [[Value]]

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

    public var needsArea: Bool { frames.joined().contains(where: \.isPart) }

    public func target(window: CGRect, area: CGRect) -> CGRect {
        let rects = frames.map { Self.rect($0, in: area) }
        guard rects.count > 1, let held = rects.firstIndex(where: { Self.near($0, window) }) else { return rects[0] }
        return rects[(held + 1) % rects.count]
    }

    public static func origin(of size: CGSize, target: CGRect, area: CGRect) -> CGPoint {
        CGPoint(
            x: edge(target.minX, target.maxX, length: size.width, area: (area.minX, area.maxX)),
            y: edge(target.minY, target.maxY, length: size.height, area: (area.minY, area.maxY))
        )
    }

    public static func start(of size: CGSize, from origin: CGPoint, home: CGRect, area: CGRect) -> CGPoint {
        let room = size.width <= home.width && size.height <= home.height ? home : area
        return CGPoint(
            x: max(room.minX, min(origin.x, room.maxX - size.width)),
            y: max(room.minY, min(origin.y, room.maxY - size.height))
        )
    }

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
