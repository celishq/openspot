import SwiftUI
import XCTest
@testable import OpenspotCore

final class SpringEndTests: XCTestCase {
    override func tearDown() {
        SpotTokens.take(Theme().layout)
    }

    func testThePathOfTheRuleIsTheSpringOfSwiftUI() {
        for (duration, bounce) in [(MotionTokens.grow, 0.0), (MotionTokens.press, MotionTokens.pressBounce), (MotionTokens.pop, MotionTokens.popBounce)] {
            let end = SpringEnd(duration: duration, bounce: bounce)
            let spring = Spring(duration: duration, bounce: bounce)
            for step in 0...200 {
                let time = duration * Double(step) / 50
                XCTAssertEqual(end.path(at: time).offset, 1 - spring.value(target: 1.0, time: time), accuracy: 1e-9)
                XCTAssertEqual(end.path(at: time).speed, abs(spring.velocity(target: 1.0, time: time)), accuracy: 1e-6)
            }
        }
    }

    func testEachSpringEndsWhenTheLongestTravelHasLessThanHalfAPointLeft() {
        for (duration, bounce) in [(MotionTokens.grow, 0.0), (MotionTokens.move, 0.0), (MotionTokens.press, MotionTokens.pressBounce), (MotionTokens.pop, MotionTokens.popBounce)] {
            let end = SpringEnd(duration: duration, bounce: bounce)
            let travel = MotionTokens.longestTravel
            let rest = end.path(at: end.end)
            let before = end.path(at: end.end - duration / 100)

            XCTAssertLessThan(abs(rest.offset) * travel, MotionTokens.visibleTravel)
            XCTAssertLessThan(end.reach(offset: abs(rest.offset), speed: rest.speed) * travel, MotionTokens.visibleTravel)
            XCTAssertGreaterThanOrEqual(end.reach(offset: abs(before.offset), speed: before.speed) * travel, MotionTokens.visibleTravel)
        }
    }

    func testAUnitValueEndsAtTheSameTimeWithTheMatchingFraction() {
        let end = SpringEnd(duration: MotionTokens.grow, bounce: 0)
        let rest = end.path(at: end.end)

        XCTAssertLessThan(abs(rest.offset), MotionTokens.restFraction)
        XCTAssertTrue(end.isDone(offset: abs(rest.offset), speed: rest.speed, travel: 1))
        XCTAssertFalse(end.isDone(offset: abs(rest.offset) * 2, speed: rest.speed * 2, travel: 1))
    }

    func testTheEndFollowsTheDurationOfATheme() throws {
        let plain = SpringEnd(duration: MotionTokens.grow, bounce: 0).end
        let folder = try temporaryFolder()
        let copy = folder.appendingPathComponent("themes/openspot.theme/theme.toml")
        try FileManager.default.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "[advanced]\ngrow = \(SpotTokens.layout.motion.grow * 2)\n".write(to: copy, atomically: true, encoding: .utf8)
        SpotTokens.take(ThemeFolder.read(builtIn: builtInURL, copy: copy).layout)

        XCTAssertEqual(SpringEnd(duration: MotionTokens.grow, bounce: 0).end, plain * 2, accuracy: plain / 100)
    }

    @MainActor
    func testSlowMotionMakesTheEndTenTimesLater() {
        let plain = SpringEnd(duration: MotionTokens.grow, bounce: 0).end
        MotionTokens.toggleSlowMotion()
        defer { MotionTokens.toggleSlowMotion() }

        XCTAssertEqual(SpringEnd(duration: MotionTokens.grow, bounce: 0).end, plain * MotionTokens.slowMotion, accuracy: plain / 100)
    }

    func testARetargetWithSpeedEndsLaterThanAStartFromRest() {
        let end = SpringEnd(duration: MotionTokens.grow, bounce: 0)

        XCTAssertGreaterThan(end.reach(offset: 0.001, speed: 5), end.reach(offset: 0.001, speed: 0))
        XCTAssertEqual(end.reach(offset: 0.25, speed: 0), 0.25, accuracy: 1e-12)
        XCTAssertFalse(end.isDone(offset: 0, speed: 5, travel: 1))
    }

    private let builtInURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Themes/openspot.theme/theme.toml")
}
