import AppKit
import SwiftUI
import XCTest
@testable import OpenspotCore

@MainActor
final class SpotSpringTests: XCTestCase {
    private let frame = 1.0 / 120

    func testAnOpenMovesAsThePlainSpringUntilItsEndAndThenRests() {
        let travel = MotionTokens.longestTravel
        let plain = run(plainSpring(duration: MotionTokens.grow, bounce: 0), presses: [(0, travel)])
        let ended = run(spotSpring(duration: MotionTokens.grow, bounce: 0), presses: [(0, travel)])
        let end = ended.removed[0]

        XCTAssertEqual(Array(ended.values[..<end]), Array(plain.values[..<end]))
        XCTAssertLessThan(travel - plain.values[end], MotionTokens.visibleTravel)
        XCTAssertGreaterThanOrEqual(travel - plain.values[end - 2], MotionTokens.visibleTravel)
        XCTAssertTrue(ended.values[end...].allSatisfy { $0 == travel })
        XCTAssertGreaterThanOrEqual(Double(end) * frame, SpringEnd(duration: MotionTokens.grow, bounce: 0).end() ?? 0)
        XCTAssertLessThan(Double(end) * frame, (SpringEnd(duration: MotionTokens.grow, bounce: 0).end() ?? 0) + 6 * frame)
        XCTAssertLessThan(Double(end) * frame, Double(plain.removed[0]) * frame * 0.75)
    }

    func testAUnitValueEndsAtTheSameTimeAsTheLongestTravel() {
        let unit = run(spotSpring(duration: MotionTokens.grow, bounce: 0), presses: [(0, 1)])
        let points = run(spotSpring(duration: MotionTokens.grow, bounce: 0), presses: [(0, MotionTokens.longestTravel)])

        XCTAssertEqual(unit.removed[0], points.removed[0], accuracy: 1)
    }

    func testEachSpringOfTheAppEndsWithLessThanHalfAPointLeft() {
        let travel = MotionTokens.longestTravel
        for (duration, bounce) in [(MotionTokens.move, 0.0), (MotionTokens.press, MotionTokens.pressBounce), (MotionTokens.pop, MotionTokens.popBounce)] {
            let plain = run(plainSpring(duration: duration, bounce: bounce), presses: [(0, travel)])
            let ended = run(spotSpring(duration: duration, bounce: bounce), presses: [(0, travel)])
            let end = ended.removed[0]

            XCTAssertEqual(Array(ended.values[..<end]), Array(plain.values[..<end]))
            XCTAssertLessThan(plain.values[end...].map { abs(travel - $0) }.max() ?? 0, MotionTokens.visibleTravel)
            XCTAssertLessThan(end, plain.removed[0])
        }
    }

    func testARetargetInMidFlightKeepsTheValueAndTheSpeedOfThePlainSpring() {
        let travel = MotionTokens.longestTravel
        let presses = [(0, travel), (12, 0.0)]
        let plain = run(plainSpring(duration: MotionTokens.grow, bounce: 0), presses: presses)
        let ended = run(spotSpring(duration: MotionTokens.grow, bounce: 0), presses: presses)
        let end = ended.removed.max() ?? 0

        XCTAssertEqual(Array(ended.values[..<end]), Array(plain.values[..<end]))
        XCTAssertLessThan(plain.values[end...].map(abs).max() ?? 0, MotionTokens.visibleTravel)
        XCTAssertTrue(ended.values[end...].allSatisfy { $0 == 0 })
        XCTAssertLessThan(end, plain.removed.max() ?? 0)
    }

    func testRapidPressesKeepThePlainSpringAndEndSoonAfterTheLast() {
        let travel = MotionTokens.longestTravel
        let presses = [(0, travel), (18, 0.0), (36, travel), (54, 0.0), (72, travel)]
        let plain = run(plainSpring(duration: MotionTokens.grow, bounce: 0), presses: presses)
        let ended = run(spotSpring(duration: MotionTokens.grow, bounce: 0), presses: presses)
        let end = ended.removed.max() ?? 0

        XCTAssertEqual(Array(ended.values[..<end]), Array(plain.values[..<end]))
        XCTAssertLessThan(travel - (plain.values[end...].min() ?? 0), MotionTokens.visibleTravel)
        XCTAssertLessThan(end, plain.removed.max() ?? 0)
    }

    func testEachSpringOfTheAppIsLogicallyCompleteOnTheSameFrameAsThePlainSpring() {
        let travel = MotionTokens.longestTravel
        let curves = [(MotionTokens.grow, 0.0), (MotionTokens.move, 0.0), (MotionTokens.press, MotionTokens.pressBounce), (MotionTokens.pop, MotionTokens.popBounce)]
        for (duration, bounce) in curves {
            for presses in [[(0, travel)], [(0, travel), (12, 0.0)]] {
                let plain = run(plainSpring(duration: duration, bounce: bounce), presses: presses)
                let ended = run(spotSpring(duration: duration, bounce: bounce), presses: presses)

                XCTAssertEqual(ended.logical.count, presses.count)
                XCTAssertEqual(ended.logical, plain.logical)
                XCTAssertLessThanOrEqual(ended.logical.max() ?? 0, ended.removed.max() ?? 0)
            }
        }
    }

    func testTheSheetsContentFadesInOverAbout150MillisecondsOfTheOpenAndNoEarlierThanTheSheetsLook() {
        let progress = run(plainSpring(duration: MotionTokens.grow, bounce: 0), presses: [(0, 1)]).values
        func time(_ look: (Double) -> Double, reaching share: Double) -> Double {
            Double(progress.firstIndex { look($0) >= share } ?? progress.count) * frame
        }
        let look = { SheetMorph.contentLook(at: $0, isOpen: true) }
        let span = time(look, reaching: 0.9) - time(look, reaching: 0.05)

        XCTAssertGreaterThanOrEqual(time(look, reaching: 0.05), time(SheetMorph.sheetLook(at:), reaching: 0.05))
        XCTAssertGreaterThanOrEqual(span, 0.13)
        XCTAssertLessThanOrEqual(span, 0.17)
    }

    func testTheSheetsContentFadesOutOverAbout125MillisecondsOfTheClose() {
        let progress = run(SpotMotion.grow(isOpen: false), presses: [(0, -1)]).values.map { 1 + $0 }
        func time(falling share: Double) -> Double {
            Double(progress.firstIndex { SheetMorph.contentLook(at: $0, isOpen: false) <= share } ?? progress.count) * frame
        }
        let span = time(falling: 0.05) - time(falling: 0.9)

        XCTAssertGreaterThanOrEqual(span, 0.11)
        XCTAssertLessThanOrEqual(span, 0.14)
    }

    private func plainSpring(duration: Double, bounce: Double) -> Animation {
        SpotMotion.plainSpring(duration: duration, bounce: bounce)
    }

    private func spotSpring(duration: Double, bounce: Double) -> Animation {
        Animation(SpotSpring(base: plainSpring(duration: duration, bounce: bounce), end: SpringEnd(duration: duration, bounce: bounce)))
    }

    private func run(_ animation: Animation, presses: [(frame: Int, target: Double)], frames: Int = 240) -> (values: [Double], removed: [Int], logical: [Int]) {
        let place = Place()
        let host = NSHostingView(rootView: Stage(place: place))
        host.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        host._renderForTest(interval: 0)
        var values: [Double] = []
        var removed: [Int] = []
        var logical: [Int] = []
        for index in 0..<frames {
            for press in presses where press.frame == index {
                var transaction = Transaction(animation: animation)
                transaction.addAnimationCompletion(criteria: .logicallyComplete) { logical.append(values.count) }
                transaction.addAnimationCompletion(criteria: .removed) { removed.append(values.count) }
                withTransaction(transaction) { place.target = press.target }
            }
            host._renderForTest(interval: frame)
            values.append(place.shown)
        }
        return (values, removed, logical)
    }
}

@MainActor
private final class Place: ObservableObject {
    @Published var target = 0.0
    var shown = 0.0
}

private struct Stage: View {
    @ObservedObject var place: Place

    var body: some View {
        Mark(value: place.target, place: place)
    }
}

private struct Mark: View, @preconcurrency Animatable {
    var value: Double
    let place: Place

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        place.shown = value
        return Color.clear
    }
}
