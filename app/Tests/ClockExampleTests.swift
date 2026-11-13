import XCTest
@testable import OpenspotCore

/// Proves the World clock example with its real script and a fake `date`: it shows the time of its zone in the menu bar,
/// and prints it again when a new minute starts.
final class ClockExampleTests: SampleSpotsCase {
    func testItShowsTheTimeOfItsZoneAndPrintsItAgainAtTheNextMinute() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-clock-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try """
        #!/bin/sh
        case "$1" in
          +%-S) echo 59 ;;
          *) [ "$TZ" = Asia/Tokyo ] && echo 22:15 || echo 13:15 ;;
        esac
        """.writeScript(to: folder.appendingPathComponent("date"))
        let clock = try example("World clock")
        let process = ScriptProcess(url: clock.url, mode: .stays, limit: 10, stopPause: 0.2, variables: ["PATH": "\(folder.path):/usr/bin:/bin"])
        defer { process.end() }
        var frames = process.start().makeAsyncIterator()

        process.send(.read, id: 1)
        var answer: String?
        var tick: String?
        var hasEnded = false
        while answer == nil || tick == nil, let frame = try await frames.next() {
            let output = SpotOutput(text: frame)
            if output.ends == ["1"] { hasEnded = true }
            guard output.isPicture else { continue }
            if hasEnded { tick = frame } else { answer = frame }
        }

        XCTAssertTrue(clock.canShowInMenuBar)
        XCTAssertEqual(answer, "text=time\ntitle=22:15\ndetail=Tokyo\n")
        XCTAssertEqual(tick, "text=time\ntitle=22:15\ndetail=Tokyo\n")
    }
}
