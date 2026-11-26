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
        let frame = Frame(text: "number=cpu\nclass=bar:flex\nvalue=12\nmax=100\n\nitem=note\ntitle=Busy\n")

        XCTAssertFalse(frame.tree.isWritten)
        XCTAssertEqual(frame.items.map(\.run), ["cpu", "note"])
        XCTAssertEqual(frame.parts, [])
    }


    func testABoxInAGroupAndABlockInAnItemAreReported() {
        let text = "frame=\n\nitems=list\n\nbox=group\nparent=list\ntitle=Group\n\nbox=inner\nparent=group\n\nitem=a\nparent=group\ntitle=A\n\ntext=b\nparent=a\ntitle=B\n"

        XCTAssertEqual(FrameCheck(text: text).partFaults, [
            "the box inner sits inside the group group, so it and the blocks inside it do not show. A group is one level deep",
            "the block b sits inside the item a, so it does not show. An item is one block"
        ])
    }

    func testATextInsideItemsIsReportedAsAnItem() {
        let text = "frame=\nclass=gap-part\n\ntext=head\ntitle=Photos\n\nitems=list\n\ntext=beach\nparent=list\ntitle=Beach\n\nitem=sea\nparent=list\ntitle=Sea\nroute=sea\nopen.title=Show\n"

        XCTAssertEqual(FrameCheck(text: text).partFaults, ["the text beach sits in a list, where each row is an item. Print it as item=beach"])
    }

    func testATextInAFrameWithNoLayoutIsReportedAsAnItem() {
        XCTAssertEqual(FrameCheck(text: "text=a\ntitle=A\n\nitem=b\ntitle=B\n").partFaults, [
            "the text a sits in a list, where each row is an item. Print it as item=a"
        ])
    }

    func testAnItemOutsideAListIsReportedAsText() {
        let text = "frame=\nclass=gap-part\n\nitem=head\ntitle=Photos\n\nitems=list\n\nitem=sea\nparent=list\ntitle=Sea\n"

        XCTAssertEqual(FrameCheck(text: text).partFaults, ["the item head sits outside a list, so it is no row. Print it as text=head"])
    }
}
