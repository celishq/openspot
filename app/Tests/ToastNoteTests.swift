import XCTest
@testable import OpenspotCore

final class ToastNoteTests: XCTestCase {
    func testTheHeadBlockGivesTheIdTheWordsAndAction() throws {
        let note = try ToastNote(.init(view: "toast=upload\ntitle=Uploading\naction=again\n"))

        XCTAssertEqual(note.id, "upload")
        XCTAssertEqual(note.words, "Uploading")
        XCTAssertEqual(note.action, "again")
    }

    func testWordsAloneLeaveWithNoIdAndNoAction() {
        let note = ToastNote(words: "Saved")

        XCTAssertNil(note.id)
        XCTAssertEqual(note.words, "Saved")
        XCTAssertNil(note.action)
    }

    func testAHeadWithNothingToShowIsAFault() {
        XCTAssertThrowsError(try ToastNote(.init(view: "toast=upload\naction=again\n")))
    }

    func testAnUnknownKeyOfTheHeadIsAFault() {
        XCTAssertThrowsError(try ToastNote(.init(view: "toast=upload\ntitle=Up\nlinger=5\n")))
    }

    func testTheBlocksAfterTheHeadAreTheTreeItDraws() throws {
        let note = try ToastNote(.init(view: "toast=upload\nclass=flex-row gap-2\n\nnumber=done\nvalue=40\nmax=100\ntype=ring\n\ntext=words\ntitle=Uploading\n"))

        let tree = try XCTUnwrap(note.tree)
        XCTAssertEqual(tree.children, ["done", "words"])
        XCTAssertEqual(tree.faults, [])
        XCTAssertEqual(tree.style.arrangement, .row)
    }

    func testAToastWithWordsAloneHasNoTree() throws {
        XCTAssertNil(ToastNote(words: "Saved").tree)
        XCTAssertNil(try ToastNote(.init(view: "toast=up\ntitle=Up\n")).tree)
    }

    func testABlockOfAKindOpenspotLacksIsAFault() {
        XCTAssertThrowsError(try ToastNote(.init(view: "toast=up\n\nweek=w\ntitle=This week\n")))
    }

    func testAToastClassTakesTheToastPlace() throws {
        let note = try ToastNote(.init(view: "toast=up\n\ntext=a\ntitle=A\nclass=hidden toast:flex\n"))

        let node = try XCTUnwrap(note.tree?.node("a"))
        XCTAssertEqual(node.style.resolved(for: [.toast]).isHidden, false)
    }
}
