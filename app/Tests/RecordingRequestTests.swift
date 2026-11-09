import XCTest
@testable import OpenspotCore

final class RecordingRequestTests: XCTestCase {
    func testAStartCarriesItsTargetInputsAndFilesWhole() {
        let plans = [
            RecordingRequest.Plan(target: .display(3), inputs: [], cursor: false, file: "/a/Talk.mp4"),
            RecordingRequest.Plan(target: .window(4012), inputs: [.mic(nil), .system], cursor: true, file: "/a/b c.mov", events: "/a/e.jsonl"),
            RecordingRequest.Plan(target: .area(CGRect(x: 10, y: 20.5, width: 300, height: 200)), inputs: [.mic("AppleUSB:2:1"), .camera("0x14")], cursor: false, file: "/a/T.mp4", camera: "/a/T.camera.mov")
        ]
        for plan in plans {
            XCTAssertEqual(RecordingRequest(text: RecordingRequest.start(plan).text), .start(plan))
        }
    }

    func testAStopAndAStatusAreOneWord() {
        XCTAssertEqual(RecordingRequest(text: RecordingRequest.stop.text), .stop)
        XCTAssertEqual(RecordingRequest(text: RecordingRequest.status.text), .status)
    }

    func testARequestWithNoTargetOrNoFileIsNotRead() {
        XCTAssertNil(RecordingRequest(text: "do=start\nfile=/a.mp4\n"))
        XCTAssertNil(RecordingRequest(text: "do=start\ndisplay=1\n"))
        XCTAssertNil(RecordingRequest(text: "do=start\narea=1 2 3\nfile=/a.mp4\n"))
        XCTAssertNil(RecordingRequest(text: "do=pause\n"))
    }
}
