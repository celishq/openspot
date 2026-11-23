import XCTest
@testable import OpenspotCore

final class SheetMorphTests: XCTestCase {
    private let morph = SheetMorph(card: CGRect(x: 165, y: 165, width: 64, height: 64), sheet: CGRect(x: 90, y: 90, width: 289, height: 430))

    func testTheShapeGrowsFromTheCardsSizeToTheSheetsSize() {
        XCTAssertEqual(morph.size(at: 0), CGSize(width: 64, height: 64))
        XCTAssertEqual(morph.size(at: 1), CGSize(width: 289, height: 430))
        XCTAssertEqual(morph.size(at: 0.5).width, 176.5, accuracy: 0.001)
    }

    func testTheCardsLookIsGoneHalfWayAndTheSheetsLookStartsAtAFifth() {
        XCTAssertEqual(SheetMorph.cardLook(at: 0), 1)
        XCTAssertGreaterThan(SheetMorph.cardLook(at: 0.4), 0)
        XCTAssertEqual(SheetMorph.cardLook(at: 0.5), 0)
        XCTAssertEqual(SheetMorph.sheetLook(at: 0.2), 0)
        XCTAssertGreaterThan(SheetMorph.sheetLook(at: 0.25), 0)
        XCTAssertEqual(SheetMorph.sheetLook(at: 1), 1)
    }

    func testTheTwoLooksShowTogetherOnlyBetweenAFifthAndAHalf() {
        for step in 0...100 {
            let progress = Double(step) / 100
            let both = SheetMorph.cardLook(at: progress) * SheetMorph.sheetLook(at: progress) > 0
            XCTAssertEqual(both, progress > 0.2 && progress < 0.5, "at \(progress)")
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

    func testTheFieldsGlassShowsWhileAnyEdgeLiesOutsideTheShapeAndIsGoneOnceTheShapeHoldsItByAMargin() {
        let margin = SheetMorph.clearance
        let field = CGRect(x: 90, y: 90, width: 289, height: 52)
        let row = CGRect(x: 90 + margin, y: 150, width: 289 - 2 * margin, height: 40)
        XCTAssertEqual(morph.fieldGlass(of: field, at: 0), 1)
        XCTAssertEqual(morph.fieldGlass(of: field, at: 1), 1)
        XCTAssertEqual(morph.fieldGlass(of: row, at: 1), 0)
        XCTAssertEqual(morph.fieldGlass(of: row.insetBy(dx: -margin / 2, dy: 0), at: 1), 0.5, accuracy: 0.001)
    }

    func testTheFieldsGlassIsGoneThroughASheetThatGrowsFromTheField() {
        let fromField = SheetMorph(card: CGRect(x: 90, y: 90, width: 289, height: 52), sheet: CGRect(x: 90, y: 90, width: 289, height: 430), source: .field)
        for step in 0...10 {
            XCTAssertEqual(fromField.fieldGlass(of: CGRect(x: 90, y: 90, width: 289, height: 52), at: Double(step) / 10), 0)
        }
    }

    func testWordsThatCrossTheHeaderAreGoneWhileTheyLieAcrossIt() {
        let header = CGRect(x: 57, y: 13, width: 180, height: 36)
        let words = { (progress: Double) in CGRect(x: 120, y: 113 + 61 * CGFloat(progress), width: 150, height: 18) }
        for step in 0...100 {
            let progress = Double(step) / 100
            let corner = morph.origin(at: progress)
            let placed = header.offsetBy(dx: corner.x, dy: corner.y)
            if words(progress).minY < placed.maxY, words(progress).maxY > placed.minY {
                XCTAssertEqual(morph.crossing(of: words(progress), header: header, at: progress), 0, "at \(progress)")
            }
        }
        XCTAssertEqual(morph.crossing(of: words(0), header: header, at: 0), 1)
    }

    func testAFieldSourceShowsNoLookOfItsOwnWhileACardShowsItsLookUntilHalfWay() {
        let field = SheetMorph(card: CGRect(x: 24, y: 24, width: 289, height: 52), sheet: CGRect(x: 24, y: 24, width: 289, height: 430), source: .field)

        XCTAssertEqual(field.sourceLook(at: 0), 0)
        XCTAssertEqual(morph.sourceLook(at: 0), 1)
        XCTAssertEqual(morph.sourceLook(at: 0.5), 0)
    }

    func testTheFieldsWordsStayWholeOverAHeaderThatHasNotFadedInYet() {
        let field = SheetMorph(card: CGRect(x: 24, y: 24, width: 289, height: 52), sheet: CGRect(x: 24, y: 24, width: 289, height: 430), source: .field)
        let header = CGRect(x: 14, y: 14, width: 261, height: 36)
        let words = CGRect(x: 24, y: 41, width: 289, height: 18)

        for step in 0...100 {
            let progress = Double(step) / 100
            XCTAssertEqual(field.crossing(of: words, header: header, at: progress), 1 - SheetMorph.sheetLook(at: progress), accuracy: 0.001, "at \(progress)")
        }
    }

    func testTheBlursFootLiesUnderTheMovingShapeWithRoomForTheFooter() {
        let below = SpotTokens.halo + SpotTokens.hintBlock

        XCTAssertEqual(morph.foot(at: 0), 229 + below, accuracy: 0.001)
        XCTAssertEqual(morph.foot(at: 1), 520 + below, accuracy: 0.001)
        XCTAssertEqual(morph.foot(at: 0.5), 374.5 + below, accuracy: 0.001)
    }
}
