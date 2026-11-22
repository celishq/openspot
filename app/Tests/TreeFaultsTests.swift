import XCTest
@testable import OpenspotCore

final class TreeFaultsTests: XCTestCase {
    func testABoxWithAnUnknownKeyIsReported() {
        let text = "frame=\nclass=gap-part\n\nbox=head\nclass=flex-row\nglow=1\n\ntext=name\nparent=head\ntitle=Home\n"

        XCTAssertEqual(FrameCheck(text: text).partFaults, ["the part head has an unknown key: glow"])
    }

    func testAKeyThatOpenspotReadsTwiceOnAViewIsReportedAndAKeyOfTheViewMayRepeat() {
        let kinds = BlockKind.kinds(views: ["meter": "/spot/meter.swift"])
        let text = "frame=\n\nmeter=level\nvalue=1\nvalue=2\nday=1\nday=2\ntitle=A\ntitle=B\n"

        XCTAssertEqual(SpotCheck.brokenBlocks(in: text, kinds: kinds), [
            "the block meter=level has title twice, as a value with a new line prints. Print each value from data with openspot_kv, openspot_item or esc"
        ])
    }

    func testATextShorterThanItsWordsIsReported() {
        let text = "frame=\nclass=gap-part\n\ntext=name\ntitle=Home\ndetail=82 Mb/s\nclass=h-4\n"

        XCTAssertEqual(FrameCheck(text: text).partFaults, ["the text name is 16pt tall, so its words are cut. Give it more room"])
    }

    func testOnlyOnePartOfATreeCanBeStrong() {
        let text = "frame=\nclass=flex-row gap-part\n\nbutton=save\ntitle=Save\nclass=bg-accent\n\nbutton=send\ntitle=Send\nclass=bg-accent\n"

        XCTAssertEqual(FrameCheck(text: text).partFaults, ["only one button can use bg-accent"])
    }

    func testATitleThatMayNotFitItsPlaceInARowIsReported() {
        let switches = (1...4).map { "switch=s\($0)\ntitle=A switch with a long title \($0)\nvalue=true\n" }.joined(separator: "\n")
        let text = "frame=\nclass=flex-row gap-part\n\n" + switches

        XCTAssertEqual(FrameCheck(text: text).partFaults, (1...4).map { "the title of the part s\($0) may not fit its cell" })
        XCTAssertEqual(FrameCheck(text: "frame=\nclass=gap-part\n\n" + switches).partFaults, [])
    }

    func testATextThatTruncatesOrClampsAcceptsItsCut() {
        let title = "A text with a very long title that runs on"
        func faults(_ classes: String) -> [String] {
            FrameCheck(text: "frame=\nclass=flex-row gap-part\n\ntext=a\ntitle=\(title)\nclass=\(classes)\n\ntext=b\ntitle=\(title)\nclass=\(classes)\n").partFaults.filter { $0.contains("may not fit") }
        }

        XCTAssertEqual(faults("truncate"), [])
        XCTAssertEqual(faults("line-clamp-2"), [])
    }

    func testATreeThatScrollsIsNeverTooTall() {
        let texts = (1...20).map { "text=t\($0)\ntitle=Line \($0)\n" }.joined(separator: "\n")
        let text = "frame=\nclass=gap-part\n\nfield=note\ntype=multiline\nvalue=Hi\n\n" + texts

        XCTAssertEqual(FrameCheck(text: text).partFaults, [])
    }

    func testAFrameWhoseOnlyClassIsOneVariantOnOneBlockHasNoLayout() {
        let frame = Frame(text: "number=cpu\nclass=bar:flex\nvalue=12\nmax=100\n\ntext=note\ntitle=Busy\n")

        XCTAssertFalse(frame.tree.isWritten)
        XCTAssertEqual(frame.items.map(\.run), ["cpu", "note"])
        XCTAssertEqual(frame.parts, [])
    }
}
