import XCTest
@testable import OpenspotCore

@MainActor
final class BigPasteTests: XCTestCase {
    private static let megabyte = 1_000_000
    private static let runCount = 3

    private static let texts: [(name: String, text: String)] = [
        ("letters", String(repeating: "a", count: megabyte)),
        ("lines", String(repeating: "one line\n", count: megabyte / 9)),
        ("backslashes", String(repeating: "\\", count: megabyte)),
        ("words", String(repeating: "héllo wörld ", count: megabyte / 14))
    ]

    private var folder: URL!
    private var runs: SpotRuns!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-paste-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        runs = SpotRuns()
    }

    override func tearDown() async throws {
        runs.quit()
        try? FileManager.default.removeItem(at: folder)
    }

    private func sheet(answer: String) throws -> SpotRun {
        let url = folder.spotFile("script")
        try """
        #!/bin/sh
        # on=sheet.open
        case "$1" in
          read) printf 'field=input\\nvalue=\\n\\nfield=output\\nvalue=\\nreadonly=true\\n' ;;
          input) \(answer) ;;
        esac
        """.writeScript(to: url)
        runs.take(try SpotsFolder(url: folder).scan())
        return try XCTUnwrap(runs.sheets["script"])
    }

    private func answerTime(of sheet: SpotRun, for text: String) async throws -> TimeInterval {
        sheet.open {}
        for _ in 0..<500 where sheet.panel == nil || !sheet.calls.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        let input = try XCTUnwrap(sheet.panel?.parts.first { $0.id == "input" })
        let started = Date()
        sheet.set(input, to: text)
        while sheet.panel?.parts.first(where: { $0.id == "output" })?.value != text {
            try await Task.sleep(for: .milliseconds(1))
            if Date().timeIntervalSince(started) > 60 { break }
        }
        let time = Date().timeIntervalSince(started)
        sheet.close()
        runs.panelClosed()
        while !sheet.calls.isEmpty { try await Task.sleep(for: .milliseconds(10)) }
        return time
    }

    private func bestTime(of sheet: SpotRun, for text: String, under limit: TimeInterval) async throws -> TimeInterval {
        var best = TimeInterval.infinity
        for _ in 0..<Self.runCount where best >= limit {
            best = min(best, try await answerTime(of: sheet, for: text))
        }
        return best
    }

    func testAPasteOfOneMegabyteAnswersInUnderTenSeconds() async throws {
        let sheet = try sheet(answer: "printf 'field=output\\nvalue='; sed -n 's/^input=//p'")
        for (name, text) in Self.texts {
            let best = try await bestTime(of: sheet, for: text, under: 10)
            print("TIMING \(name) paste to answer: \(Int(best * 1000)) ms")
            XCTAssertLessThan(best, 10, name)
        }
    }

    func testAPasteOfOneMegabyteThroughTheShellHelperAnswers() async throws {
        let sheet = try sheet(answer: #". "$OPENSPOT_SH"; input=$(value input; printf x); printf 'field=output\nvalue=%s\n' "$(esc "${input%x}")""#)
        for (name, text) in Self.texts {
            let best = try await bestTime(of: sheet, for: text, under: 30)
            print("TIMING \(name) paste to answer through the helper: \(Int(best * 1000)) ms")
            XCTAssertLessThan(best, 30, name)
        }
    }
}
