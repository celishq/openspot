import XCTest
@testable import OpenspotCore

final class ToastNoteTests: XCTestCase {
    func testTheHeadBlockGivesTheIdTheWordsKeepAndAction() throws {
        let note = try ToastNote(blocks: "toast=upload\ntitle=Uploading\nkeep=true\naction=again\n")

        XCTAssertEqual(note.id, "upload")
        XCTAssertEqual(note.words, "Uploading")
        XCTAssertTrue(note.keeps)
        XCTAssertEqual(note.action, "again")
    }

    func testWordsAloneLeaveWithNoIdAndNoAction() {
        let note = ToastNote(words: "Saved")

        XCTAssertNil(note.id)
        XCTAssertEqual(note.words, "Saved")
        XCTAssertFalse(note.keeps)
        XCTAssertNil(note.action)
    }

    func testAHeadWithNothingToShowIsAFault() {
        XCTAssertThrowsError(try ToastNote(blocks: "toast=upload\nkeep=true\n"))
    }

    func testKeepTakesOnlyTrueOrFalse() {
        XCTAssertThrowsError(try ToastNote(blocks: "toast=upload\ntitle=Up\nkeep=yes\n"))
    }

    func testAnUnknownKeyOfTheHeadIsAFault() {
        XCTAssertThrowsError(try ToastNote(blocks: "toast=upload\ntitle=Up\nlinger=5\n"))
    }
}
