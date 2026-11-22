import CoreGraphics
import Foundation

public struct BoxLayout {
    public struct Child {
        public let style: Style
        let measure: (CGFloat?, CGFloat?) -> CGSize

        public init(style: Style, measure: @escaping (CGFloat?, CGFloat?) -> CGSize) {
            self.style = style
            self.measure = measure
        }
    }

    public struct Placement: Equatable {
        public let size: CGSize
        public let frames: [CGRect]
    }

    public let style: Style
    public let outset: CGFloat

    public init(style: Style, outset: CGFloat = 0) {
        self.style = style
        self.outset = outset
    }

    public func place(_ children: [Child], width: CGFloat?, height: CGFloat?) -> Placement {
        let flowing = children.indices.filter { !children[$0].style.isAbsolute }
        let flow = flowing.map { children[$0] }
        let (size, placed) = style.arrangement == .grid
            ? grid(flow, width: width, height: height)
            : style.arrangement == .row ? row(flow, width: width, height: height) : column(flow, width: width, height: height)
        var frames = Array(repeating: CGRect.zero, count: children.count)
        for (offset, index) in flowing.enumerated() { frames[index] = placed[offset] }
        let side = { (edge: Style.Edge) in (style.padding[edge]?.points(of: 0) ?? 0) + outset }
        let room = CGSize(width: (width ?? size.width) + side(.left) + side(.right), height: (height ?? size.height) + side(.top) + side(.bottom))
        for index in children.indices where children[index].style.isAbsolute {
            frames[index] = Self.pinned(children[index], in: room).offsetBy(dx: -side(.left), dy: -side(.top))
        }
        return Placement(size: size, frames: frames)
    }

    static func points(_ length: Style.Length?, of whole: CGFloat?) -> CGFloat? {
        guard let length else { return nil }
        switch length {
        case .full, .fraction: return whole.map(length.points(of:))
        default: return length.points(of: 0)
        }
    }

    static func clamped(_ width: CGFloat, _ style: Style, of whole: CGFloat?) -> CGFloat {
        let low = points(style.minWidth, of: whole) ?? 0
        let high = points(style.maxWidth, of: whole) ?? .infinity
        return max(min(width, high), low)
    }

    func alignment(of child: Child) -> Style.Alignment {
        child.style.alignSelf ?? style.items ?? .stretch
    }

    static func offset(_ alignment: Style.Alignment, size: CGFloat, in room: CGFloat) -> CGFloat {
        switch alignment {
        case .start, .stretch: 0
        case .center: (room - size) / 2
        case .end: room - size
        }
    }

    private func spread(free: CGFloat, count: Int, gap: CGFloat) -> (lead: CGFloat, gap: CGFloat) {
        let free = max(free, 0)
        return switch style.justify ?? .start {
        case .start: (0, gap)
        case .center: (free / 2, gap)
        case .end: (free, gap)
        case .between: (0, count > 1 ? gap + free / CGFloat(count - 1) : gap)
        }
    }

    private static func flexed(_ basis: [CGFloat], _ children: [Child], free: CGFloat) -> [CGFloat] {
        var sizes = basis
        if free > 0 {
            let growing = children.indices.filter { children[$0].style.grows == true }
            for index in growing { sizes[index] += free / CGFloat(growing.count) }
        } else if free < 0 {
            let shrinking = children.indices.filter { children[$0].style.shrinks != false }
            let total = shrinking.reduce(CGFloat(0)) { $0 + basis[$1] }
            guard total > 0 else { return sizes }
            for index in shrinking { sizes[index] = max(basis[index] + free * basis[index] / total, 0) }
        }
        return sizes
    }

    private func column(_ children: [Child], width: CGFloat?, height: CGFloat?) -> (CGSize, [CGRect]) {
        let gap = style.rowGap?.points(of: 0) ?? 0
        let gaps = gap * CGFloat(max(children.count - 1, 0))
        let natural = children.map { $0.measure(nil, nil) }
        let room = width ?? children.indices.map { index in
            Self.points(children[index].style.width, of: nil) ?? natural[index].width
        }.max() ?? 0
        let widths = children.indices.map { index in
            let child = children[index]
            let fixed = Self.points(child.style.width, of: room)
            let fitted = fixed ?? (alignment(of: child) == .stretch ? room : min(natural[index].width, room))
            return Self.clamped(fitted, child.style, of: room)
        }
        let basis = children.indices.map { index in
            let child = children[index]
            return Self.points(child.style.height, of: height)
                ?? (child.style.isSquare ? widths[index] : child.measure(widths[index], nil).height)
        }
        let content = basis.reduce(0, +) + gaps
        let main = height ?? content
        let heights = Self.flexed(basis, children, free: main - content)
        let (lead, step) = spread(free: main - heights.reduce(0, +) - gaps, count: children.count, gap: gap)
        var y = lead
        var frames: [CGRect] = []
        for index in children.indices {
            let x = Self.offset(alignment(of: children[index]), size: widths[index], in: room)
            frames.append(CGRect(x: x, y: y, width: widths[index], height: heights[index]))
            y += heights[index] + step
        }
        return (CGSize(width: room, height: main), frames)
    }

    private func row(_ children: [Child], width: CGFloat?, height: CGFloat?) -> (CGSize, [CGRect]) {
        let gap = style.columnGap?.points(of: 0) ?? 0
        let gaps = gap * CGFloat(max(children.count - 1, 0))
        let basis = children.map { child in
            let fixedHeight = Self.points(child.style.height, of: height)
            let fixed = Self.points(child.style.width, of: width) ?? (child.style.isSquare ? fixedHeight : nil)
            return Self.clamped(fixed ?? child.measure(nil, nil).width, child.style, of: width)
        }
        let content = basis.reduce(0, +) + gaps
        let main = width ?? content
        let widths = Self.flexed(basis, children, free: main - content).enumerated().map { index, width in
            Self.clamped(width, children[index].style, of: main)
        }
        let natural = children.indices.map { index in
            let child = children[index]
            return Self.points(child.style.height, of: height)
                ?? (child.style.isSquare ? widths[index] : child.measure(widths[index], nil).height)
        }
        let room = height ?? natural.max() ?? 0
        let (lead, step) = spread(free: main - widths.reduce(0, +) - gaps, count: children.count, gap: gap)
        var x = lead
        var frames: [CGRect] = []
        for index in children.indices {
            let child = children[index]
            let stretches = alignment(of: child) == .stretch && child.style.height == nil && !child.style.isSquare
            let tall = stretches ? room : natural[index]
            let y = Self.offset(alignment(of: child), size: tall, in: room)
            frames.append(CGRect(x: x, y: y, width: widths[index], height: tall))
            x += widths[index] + step
        }
        return (CGSize(width: main, height: room), frames)
    }
}
