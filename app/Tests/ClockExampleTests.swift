import XCTest
@testable import OpenspotCore

final class ClockExampleTests: SampleSpotsCase {
    func testItShowsTheTimeOfItsZoneAndPrintsItAgainAtTheNextMinute() async throws {
        let folder = try temporaryFolder()
        try """
        #!/bin/sh
        case "$1" in
          +%-S) echo 59 ;;
          *) [ "$TZ" = Asia/Tokyo ] && echo 22:15 || echo 13:15 ;;
        esac
        """.writeScript(to: folder.appendingPathComponent("date"))
        let clock = try spot(named: "World clock")
        let process = ScriptProcess(url: clock.url, mode: .stays, limit: 60, stopPause: 0.2, variables: ["PATH": "\(folder.path):/usr/bin:/bin"])
        defer { process.end() }
        var frames = process.start().makeAsyncIterator()

        process.send(Message(ScriptEntry.show.name), id: 1)
        var answer: String?
        var tick: String?
        var hasEnded = false
        while answer == nil || tick == nil, let frame = try await frames.next() {
            let output = Frame(text: frame)
            if output.ends == ["1"] { hasEnded = true }
            guard output.isPicture else { continue }
            if hasEnded { tick = frame } else { answer = frame }
        }

        XCTAssertTrue(clock.canShowInMenuBar)
        XCTAssertEqual(answer, "frame=\nclass=gap-part\n\ntext=time\nclass=bar:flex\ntitle=22:15\ndetail=Tokyo\n")
        XCTAssertEqual(tick, "frame=\nclass=gap-part\n\ntext=time\nclass=bar:flex\ntitle=22:15\ndetail=Tokyo\n")
    }
}
