import XCTest
@testable import OpenspotCore

final class ToastLayoutTests: XCTestCase {
    private let peek = SpotTokens.toastPeek
    private let gap = SpotTokens.toastStackGap

    func testACollapsedStackShowsTheFrontWholeAndEachOlderToastPeeksBelowIt() {
        let layout = ToastLayout(heights: [40, 40, 40], isExpanded: false)

        XCTAssertEqual(layout.places.map(\.offset), [0, peek, 2 * peek])
        XCTAssertEqual(layout.places.map(\.showsContent), [true, false, false])
        XCTAssertEqual(layout.places[0].scale, 1)
        XCTAssertGreaterThan(layout.places[1].scale, layout.places[2].scale)
        XCTAssertEqual(layout.height, 40 + 2 * peek)
    }

    func testAnOlderToastTallerThanTheFrontStillStartsBelowTheFrontsTop() {
        let layout = ToastLayout(heights: [40, 80], isExpanded: false)

        XCTAssertGreaterThanOrEqual(layout.places[1].offset, 0)
    }

    func testAnExpandedStackListsEachToastUnderTheNewerOnes() {
        let layout = ToastLayout(heights: [40, 60, 30], isExpanded: true)

        XCTAssertEqual(layout.places.map(\.offset), [0, 40 + gap, 100 + 2 * gap])
        XCTAssertEqual(layout.places.map(\.scale), [1, 1, 1])
        XCTAssertEqual(layout.places.map(\.showsContent), [true, true, true])
        XCTAssertEqual(layout.height, 130 + 2 * gap)
    }

    func testAnEmptyStackHasNoHeight() {
        XCTAssertEqual(ToastLayout(heights: [], isExpanded: false).height, 0)
    }

    func testEachToastShowsOnlyBelowTheBottomEdgeOfTheToastInFrontOfIt() {
        for isExpanded in [false, true] {
            let heights: [CGFloat] = [50, 40, 30]
            let layout = ToastLayout(heights: heights, isExpanded: isExpanded)

            XCTAssertNil(layout.places[0].edge)
            for index in 1...2 {
                XCTAssertEqual(layout.places[index].edge, layout.places[index - 1].offset + heights[index - 1])
            }
        }
    }

    func testAnExpandedStackHidesNoPartOfAToast() {
        let heights: [CGFloat] = [40, 40]
        let layout = ToastLayout(heights: heights, isExpanded: true)

        XCTAssertLessThanOrEqual(layout.places[1].edge ?? 0, layout.places[1].offset)
    }
}
