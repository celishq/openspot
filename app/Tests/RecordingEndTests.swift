import XCTest
@testable import OpenspotCore

final class RecordingEndTests: XCTestCase {
    private struct EndedScreen: MacScreen {
        let ended: ScreenRecording

        func devices() async -> [ScreenDevice] { [] }
        func shot(_ capture: ScreenCapture, in folder: URL) async throws -> URL? { nil }
        func startRecording(_ capture: ScreenCapture, in folder: URL) async throws {}
        func stopRecording() async throws -> ScreenRecording { ended }
        func recording() async throws -> ScreenRecording? { ended }
    }

    private func answers(_ ended: ScreenRecording) async -> (stop: CommandAnswer, status: CommandAnswer) {
        let calls = ScreenCalls(mac: EndedScreen(ended: ended), folder: URL(fileURLWithPath: "/"), fence: nil)
        return (await calls.stop()(), await calls.status()())
    }

    func testARecordingThatEndedByAFaultStillGivesItsFilesAndSaysTheFault() async {
        let ended = ScreenRecording(file: "/a.mp4", events: "/e.json", seconds: 4, state: .ended, fault: "The stream stopped.")

        let (stop, status) = await answers(ended)

        XCTAssertEqual(stop.output, "/a.mp4\n/e.json\n")
        XCTAssertEqual(stop.errors, "The stream stopped.\n")
        XCTAssertEqual(stop.code, 1)
        XCTAssertEqual(status.output, "state=ended\nfile=/a.mp4\nevents=/e.json\nseconds=4\n")
    }

    func testAFullInputLogIsSaidAtTheStop() async {
        let full = ScreenRecording(file: "/a.mp4", events: "/e.json", isLogFull: true)

        let (stop, _) = await answers(full)

        XCTAssertEqual(stop.output, "/a.mp4\n/e.json\n")
        XCTAssertEqual(stop.errors, "The events in /e.json stop where they reached \(InputLogSpan.byteLimit >> 20) MB.\n")
        XCTAssertEqual(stop.code, 0)
    }

    func testTheHelperWireKeepsTheEndTheFaultAndAFullLog() {
        let ended = ScreenRecording(file: "/a.mp4", events: "/e.json", seconds: 4, state: .ended, fault: "The stream stopped.", isLogFull: true)

        XCTAssertEqual(ScreenRecording(block: ended.block), ended)
    }
}
