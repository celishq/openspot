import Foundation

final class CardTilt {
    private var now = CGPoint.zero

    func next(toward pointer: CGPoint?, at time: Double) -> CGPoint {
        let goal = pointer ?? CGPoint(x: sin(time * 0.6) * 0.5, y: sin(time * 0.45) * 0.35)
        let rate = pointer == nil ? 0.05 : 0.18
        now = CGPoint(x: now.x + (goal.x - now.x) * rate, y: now.y + (goal.y - now.y) * rate)
        return now
    }
}
