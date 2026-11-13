import CoreGraphics

/// The sums and the lengths that the board's geometry needs.
extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, k: CGFloat) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }

    var length: CGFloat { (x * x + y * y).squareRoot() }

    /// This vector at length 1, or zero for a zero vector.
    var unit: CGPoint { length > 0 ? self * (1 / length) : .zero }

    /// This vector turned a quarter to the left.
    var normal: CGPoint { CGPoint(x: -y, y: x) }

    func distance(to other: CGPoint) -> CGFloat { (self - other).length }

    /// The distance to the segment from `a` to `b`.
    func distance(toSegment a: CGPoint, _ b: CGPoint) -> CGFloat {
        let along = b - a
        let squared = along.x * along.x + along.y * along.y
        guard squared > 0 else { return distance(to: a) }
        let t = max(0, min(1, ((x - a.x) * along.x + (y - a.y) * along.y) / squared))
        return distance(to: a + along * t)
    }

    /// The point where the segment `a`–`b` crosses the segment `c`–`d`, if they cross.
    static func crossing(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint) -> CGPoint? {
        let r = b - a
        let s = d - c
        let cross = r.x * s.y - r.y * s.x
        guard abs(cross) > 1e-9 else { return nil }
        let q = c - a
        let t = (q.x * s.y - q.y * s.x) / cross
        let u = (q.x * r.y - q.y * r.x) / cross
        guard (0...1).contains(t), (0...1).contains(u) else { return nil }
        return a + r * t
    }
}
