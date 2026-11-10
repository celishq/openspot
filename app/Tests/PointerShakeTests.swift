import XCTest
@testable import OpenspotCore

/// Proves which moves of the pointer are a shake (W2), with paths sampled as the Mac sends them, 120 times a second.
final class PointerShakeTests: XCTestCase {
    /// The times at which a path of the pointer fires a shake: the pointer swings this far to each side, with this many
    /// seconds for each swing, for this long.
    private func shakes(swing: CGFloat, seconds: TimeInterval, for duration: TimeInterval) -> [TimeInterval] {
        var shake = PointerShake()
        var fired: [TimeInterval] = []
        for step in 0...Int(duration * 120) {
            let time = Double(step) / 120
            let x = 700 + swing * sin(time / seconds * .pi)
            if shake.take(x: x, at: time) { fired.append(time) }
        }
        return fired
    }

    func testQuickTurnsLeftAndRightAreAShake() {
        XCTAssertEqual(shakes(swing: 80, seconds: 0.1, for: 0.7).count, 1)
    }

    func testSlowTurnsAreNoShake() {
        XCTAssertEqual(shakes(swing: 80, seconds: 0.4, for: 3), [])
    }

    func testShortTurnsAreNoShake() {
        XCTAssertEqual(shakes(swing: 15, seconds: 0.1, for: 2), [])
    }

    func testAStraightMoveIsNoShake() {
        var shake = PointerShake()

        let fired = (0...240).contains { step in shake.take(x: CGFloat(step) * 5, at: Double(step) / 120) }

        XCTAssertFalse(fired)
    }

    func testAShakeThatGoesOnFiresAgainOnlyAfterARest() {
        let fired = shakes(swing: 80, seconds: 0.1, for: 2.5)

        XCTAssertGreaterThan(fired.count, 1)
        XCTAssertTrue(zip(fired, fired.dropFirst()).allSatisfy { $1 - $0 >= PointerShake.rest })
    }
}
