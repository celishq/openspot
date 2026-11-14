import XCTest
@testable import OpenspotCore

final class SpotRunsToTests: SpotRunsCase {
    private var reports: [(id: String, report: SpotRun.Report)] = []

    private func row(_ text: String) throws -> SpotItem {
        try XCTUnwrap(TextBlock.blocks(in: text).first.flatMap(SpotItem.init(block:)))
    }

    override func setUp() async throws {
        try await super.setUp()
        runs.onReport = { [unowned self] id, report in reports.append((id, report)) }
    }

    func testAPickOfARowWithToOpensTheOtherSpotWithTheRowOnStdin() async throws {
        try script("viewer", log: "viewer-log", #"[ "$1" = open ] && printf 'toast=%s %s\n' "$2" "$(sed -n 's/^file=//p')""#)
        try script("files", log: "files-log")
        let files = try sheet("files")

        files.pick(try row("row=doc\ntitle=Doc\nfile=/tmp/doc.txt\npush.spot=viewer\n"))

        try await wait("the toast of the viewer") { self.toasts(of: "viewer").count == 1 }
        XCTAssertEqual(toasts(of: "viewer"), ["doc /tmp/doc.txt"])
        try await allEnded()
        XCTAssertEqual(log("viewer-log"), ["open doc"])
        XCTAssertEqual(log("files-log"), [])
    }

    func testTheOtherSpotGetsEachFieldOfTheRow() async throws {
        try script("viewer", log: "viewer-log", #"[ "$1" = open ] && printf 'toast=%s\n' "$(tr '\n' ' ' | sed 's/ *$//')""#)
        try script("files", log: "files-log")
        let files = try sheet("files")

        files.pick(try row("row=doc\ntitle=Doc\nfile=/tmp/doc.txt\npush.spot=viewer\n"))

        try await wait("the toast of the viewer") { self.toasts(of: "viewer").count == 1 }
        XCTAssertEqual(toasts(of: "viewer"), ["row=doc title=Doc file=/tmp/doc.txt push.spot=viewer"])
    }

    func testARowToASpotThatIsNotThereFailsOnItsOwnSpot() async throws {
        try script("files", log: "files-log")
        let files = try sheet("files")

        files.pick(try row("row=doc\npush.spot=gone\n"))

        try await wait("the failure") { !self.failures(of: "files").isEmpty }
        XCTAssertEqual(failures(of: "files"), ["Files hands this row to `gone`, which is not on. Turn it on, then try again."])
        try await allEnded()
        XCTAssertEqual(log("files-log"), [])
    }

    func testARowWithNoToStillGoesToItsOwnSpot() async throws {
        try script("files", log: "files-log")
        let files = try sheet("files")

        files.pick(try row("row=doc\n"))

        try await wait("the call of its own spot") { self.log("files-log") == ["open doc"] }
    }

    private func toasts(of id: String) -> [String] {
        reports.compactMap { $0.id == id ? { if case .toast(let text) = $0 { text } else { nil } }($0.report) : nil }
    }

    private func failures(of id: String) -> [String] {
        reports.compactMap { $0.id == id ? { if case .failure(let text) = $0 { text } else { nil } }($0.report) : nil }
    }
}
