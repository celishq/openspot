import XCTest
@testable import OpenspotCore

final class SheetMorphTests: XCTestCase {
    private let morph = SheetMorph(card: CGRect(x: 165, y: 165, width: 64, height: 64), sheet: CGRect(x: 90, y: 90, width: 289, height: 430))

    func testTheShapeGrowsFromTheCardsSizeToTheSheetsSize() {
        XCTAssertEqual(morph.size(at: 0), CGSize(width: 64, height: 64))
        XCTAssertEqual(morph.size(at: 1), CGSize(width: 289, height: 430))
        XCTAssertEqual(morph.size(at: 0.5).width, 176.5, accuracy: 0.001)
    }

    func testTheCardsLookIsGoneHalfWayAndTheSheetsLookStartsThere() {
        XCTAssertEqual(SheetMorph.cardLook(at: 0), 1)
        XCTAssertEqual(SheetMorph.cardLook(at: 0.5), 0)
        XCTAssertEqual(SheetMorph.sheetLook(at: 0.5), 0)
        XCTAssertEqual(SheetMorph.sheetLook(at: 1), 1)
    }

    func testTheTwoLooksNeverShowTogether() {
        for step in 0...100 {
            let progress = Double(step) / 100
            XCTAssertEqual(SheetMorph.cardLook(at: progress) * SheetMorph.sheetLook(at: progress), 0, "at \(progress)")
        }
    }

    func testAPartMovesFromItsPlaceOnTheCardToItsPlaceInTheSheet() {
        let onCard = CGSize(width: 1, height: 12)
        XCTAssertEqual(SheetMorph.place(onCard: onCard, at: 0), onCard)
        XCTAssertEqual(SheetMorph.place(onCard: onCard, at: 1), .zero)
        XCTAssertEqual(SheetMorph.place(onCard: onCard, at: 0.25), CGSize(width: 0.75, height: 9))
    }

    func testAPartWithNoPlaceOnTheCardShowsOnlyOnceTheShapeHoldsAllOfIt() {
        let words = CGRect(x: 57, y: 13, width: 62, height: 16)
        XCTAssertEqual(morph.shown(words, at: 0), 0)
        XCTAssertEqual(morph.shown(words, at: 1), 1)
        for step in 0...100 {
            let progress = Double(step) / 100
            let room = morph.size(at: progress)
            if room.width < words.maxX || room.height < words.maxY { XCTAssertEqual(morph.shown(words, at: progress), 0, "at \(progress)") }
        }
    }

    func testARowAsWideAsTheSheetShowsWholeWhenTheSheetIsOpen() {
        let row = CGRect(x: 13, y: 61, width: 263, height: 40)
        XCTAssertEqual(morph.shown(row, at: 1), 1)
        XCTAssertEqual(morph.shown(row, at: 0.9), 0)
    }

    func testAPartThatGrowsInPlaceNeverCrossesTheShapesEdge() {
        let button = CGRect(x: 240, y: 13, width: 36, height: 36)
        for step in 0...100 {
            let progress = Double(step) / 100
            let scale = CGFloat(morph.growth(of: button, at: progress))
            let room = morph.size(at: progress)
            guard scale > 0 else { continue }
            XCTAssertLessThanOrEqual(button.midX + button.width / 2 * scale, room.width + 0.001, "at \(progress)")
            XCTAssertLessThanOrEqual(button.midY + button.height / 2 * scale, room.height + 0.001, "at \(progress)")
        }
        XCTAssertEqual(morph.growth(of: button, at: 1), 1)
    }

    func testTheWordsThatCrossTheHeaderAreGoneWhileTheyPassIt() {
        XCTAssertEqual(SheetMorph.crossing(at: 0), 1)
        XCTAssertEqual(SheetMorph.crossing(at: 0.25), 0)
        XCTAssertEqual(SheetMorph.crossing(at: 0.5), 0)
        XCTAssertEqual(SheetMorph.crossing(at: 1), 1)
    }
}
