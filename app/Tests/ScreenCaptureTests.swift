import XCTest
@testable import OpenspotCore

final class ScreenCaptureTests: XCTestCase {
    private func shot(_ words: String) -> ScreenCapture? {
        ScreenCapture(words: words.split(separator: " ").map(String.init), records: false)
    }

    private func recording(_ words: String) -> ScreenCapture? {
        ScreenCapture(words: words.split(separator: " ").map(String.init), records: true)
    }

    func testNoWordsLetThePersonPickAnySource() {
        XCTAssertEqual(shot(""), ScreenCapture(source: .any))
    }

    func testASourceWithNoValueLetsThePersonPickOneOfItsKind() {
        XCTAssertEqual(shot("display")?.source, .display(nil))
        XCTAssertEqual(shot("window")?.source, .window(nil))
        XCTAssertEqual(shot("area")?.source, .area(nil))
    }

    func testASourceWithAValueIsFixed() {
        XCTAssertEqual(shot("display:2")?.source, .display(2))
        XCTAssertEqual(shot("window:front")?.source, .window(.front))
        XCTAssertEqual(shot("window:4012")?.source, .window(.id(4012)))
        XCTAssertEqual(shot("area:0,0,1/2,1")?.source, .area(WindowMove(words: ["0 0 1/2 1"])))
        XCTAssertEqual(shot("area:10,20,300,200")?.source, .area(WindowMove(words: ["10 20 300 200"])))
    }

    func testABadSourceIsRefusedAndNotTakenForAFile() {
        XCTAssertNil(shot("window:top"))
        XCTAssertNil(shot("display:main"))
        XCTAssertNil(shot("area:0,0,1"))
        XCTAssertNil(shot("area:0,0,0,1"))
        XCTAssertNil(shot("area:"))
        XCTAssertNil(shot("display window"))
    }

    func testAShotTakesTheCursorAndAFileInAnyOrder() {
        XCTAssertEqual(shot("window:front --cursor a.png"), ScreenCapture(source: .window(.front), cursor: true, file: "a.png"))
        XCTAssertEqual(shot("a.png display"), ScreenCapture(source: .display(nil), file: "a.png"))
        XCTAssertNil(shot("a.png b.png"))
        XCTAssertNil(shot("--cursor --cursor"))
        XCTAssertNil(shot("--sound"))
    }

    func testAShotTakesNoInputAndNoEvents() {
        XCTAssertNil(shot("mic"))
        XCTAssertNil(shot("system"))
        XCTAssertNil(shot("camera"))
        XCTAssertNil(shot("--events e.jsonl"))
    }

    func testARecordingTakesInputsEventsAndAFile() {
        XCTAssertEqual(
            recording("display:1 mic system camera:0x1420000:05ac --events e.jsonl --cursor talk.mp4"),
            ScreenCapture(source: .display(1), inputs: [.mic(nil), .system, .camera("0x1420000:05ac")], cursor: true, events: "e.jsonl", file: "talk.mp4")
        )
        XCTAssertEqual(recording("mic:BuiltInMicrophoneDevice")?.inputs, [.mic("BuiltInMicrophoneDevice")])
        XCTAssertEqual(recording("camera")?.inputs, [.camera(nil)])
    }

    func testARecordingRefusesTwoInputsOfOneKindAndAnEmptyValue() {
        XCTAssertNil(recording("mic mic:a"))
        XCTAssertNil(recording("system system"))
        XCTAssertNil(recording("camera camera"))
        XCTAssertNil(recording("mic:"))
        XCTAssertNil(recording("camera:"))
        XCTAssertNil(recording("system:loud"))
        XCTAssertNil(recording("--events"))
        XCTAssertNil(recording("--events a.jsonl --events b.jsonl"))
    }
}
