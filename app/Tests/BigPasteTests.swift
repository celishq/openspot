import XCTest
@testable import OpenspotCore

/// Proves C6 with real processes: a paste of 1 MB goes through each step of its path, and its answer shows in under 1 second
/// in a Debug build. Each run prints the time of each step.
@MainActor
final class BigPasteTests: XCTestCase {
    private static let megabyte = 1_000_000
    private static let chunk = 65_536
    private static let runCount = 3

    /// Each form of text that a loop over each byte or each escape makes slow.
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

    private func milliseconds(_ step: String, of name: String, _ work: () throws -> Void) rethrows {
        let started = Date()
        try work()
        print("TIMING \(name) \(step): \(Int(Date().timeIntervalSince(started) * 1000)) ms")
    }

    /// A sheet that answers a change of `input` with its value in `output`, with this body for the answer.
    private func sheet(answer: String) throws -> SpotSheet {
        let url = folder.appendingPathComponent("script.sh")
        try """
        #!/bin/sh
        # read=sheet
        case "$1" in
          read) printf 'part=input\\ntext=\\n\\npart=output\\ntext=\\nreadonly=true\\n' ;;
          input) \(answer) ;;
        esac
        """.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        runs.take(try PluginFolder(url: folder).scan())
        return try XCTUnwrap(runs.sheets["script"])
    }

    /// The time from the paste to its answer in the sheet, which holds the pause of 300 ms for text (C4).
    private func answerTime(of sheet: SpotSheet, for text: String) async throws -> TimeInterval {
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

    func testEachStepOfAPasteOfOneMegabyteGivesBackTheText() async throws {
        for (name, text) in Self.texts {
            var panel = try XCTUnwrap(SpotPanel(output: PluginOutput(text: "part=input\ntext=\n\npart=output\ntext=\n")))
            var values = ""
            try milliseconds("panel set", of: name) { panel.set(text, of: "input") }
            milliseconds("stdin block", of: name) { values = panel.values }
            var sent: (arguments: [String], input: String?) = ([], nil)
            milliseconds("arguments", of: name) { sent = SpotAction.set("input", to: text).sent(input: values) }
            XCTAssertEqual(sent.arguments, ["input"])

            let answer = TextBlock(fields: [.init(key: "part", value: "output"), .init(key: "text", value: text)]).text
            let url = folder.appendingPathComponent("echo.sh")
            try "#!/bin/sh\ncat\n".write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            let started = Date()
            let echoed = try await ScriptProcess.output(url: url, input: answer, limit: 30)
            print("TIMING \(name) process with cat: \(Int(Date().timeIntervalSince(started) * 1000)) ms")
            XCTAssertEqual(echoed, answer)

            let data = Data(answer.utf8)
            var frame: String?
            milliseconds("frame read", of: name) {
                var reader = SheetFrameReader()
                for start in stride(from: 0, to: data.count, by: Self.chunk) {
                    XCTAssertEqual(reader.read(data[start..<min(start + Self.chunk, data.count)]), [])
                }
                frame = reader.finish()
            }
            XCTAssertEqual(frame, answer)

            var blocks: [TextBlock] = []
            milliseconds("block parse", of: name) { blocks = TextBlock.blocks(in: answer) }
            XCTAssertEqual(blocks.first?.value("text"), text)

            var output = PluginOutput(text: "")
            milliseconds("output", of: name) { output = PluginOutput(text: answer) }
            milliseconds("panel merge", of: name) { panel.merge(output, keeping: "input") }
            XCTAssertEqual(panel.parts.first { $0.id == "output" }?.value, text)
        }
    }

    func testAPasteOfOneMegabyteAnswersInUnderOneSecond() async throws {
        let sheet = try sheet(answer: "printf 'part=output\\ntext='; sed -n 's/^input=//p'")
        for (name, text) in Self.texts {
            var best = TimeInterval.infinity
            for _ in 0..<Self.runCount {
                best = min(best, try await answerTime(of: sheet, for: text))
            }
            print("TIMING \(name) paste to answer: \(Int(best * 1000)) ms")
            XCTAssertLessThan(best, 1, name)
        }
    }

    func testAPasteOfOneMegabyteThroughTheShellHelperAnswers() async throws {
        let sheet = try sheet(answer: #". "$OPENSPOT_SH"; input=$(value input; printf x); printf 'part=output\ntext=%s\n' "$(esc "${input%x}")""#)
        for (name, text) in Self.texts {
            var best = TimeInterval.infinity
            for _ in 0..<Self.runCount {
                best = min(best, try await answerTime(of: sheet, for: text))
            }
            print("TIMING \(name) paste to answer through the helper: \(Int(best * 1000)) ms")
            XCTAssertLessThan(best, 5, name)
        }
    }
}
