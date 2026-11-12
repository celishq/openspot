import XCTest
@testable import OpenspotCore

/// Proves what the playground shows of each call: the runs tell it each call, and it prints each part of the call.
@MainActor
final class PlaygroundCallTests: SpotRunsCase {
    func testTheRunsTellEachCallWithItsPartsAlsoAQuietOne() async throws {
        try script(header: "on=sheet.open\non=sheet.text", "echo 'slow disk' >&2\nprintf 'row=a\\ntitle=%s\\n' \"$OPENSPOT_VALUE\"")
        var calls: [PlaygroundCall] = []
        runs.onCall = { calls.append(PlaygroundCall(record: $0, reason: $1)) }
        let sheet = try sheet()

        sheet.open(onReady: {})
        try await wait("the read") { calls.count == 1 }
        sheet.search("rep")
        try await wait("the search") { calls.count == 2 }

        XCTAssertEqual(calls[0].lines.dropLast(), ["$ read · OPENSPOT_REASON=sheet.open", "> row=a", "> title=", "! slow disk"])
        XCTAssertTrue(calls[0].lines.last?.hasPrefix("= ") == true)
        XCTAssertEqual(calls[1].lines.first, "$ read · OPENSPOT_REASON=sheet.text OPENSPOT_VALUE=rep")
        XCTAssertTrue(calls[1].lines.contains("< search=rep"), "\(calls[1].lines)")
    }

    func testACallPrintsEachArgumentAndHowItEnded() {
        let record = CallLog.Record(spot: "a", arguments: ["move", "row 1", "true"], input: nil, frames: ["toast=Hi\n", "text=t\n"], errors: "", end: .failed("It took too long."), started: Date(), seconds: 1)

        XCTAssertEqual(PlaygroundCall(record: record, reason: nil).lines, ["$ move 'row 1' true", "> toast=Hi", "> ---", "> text=t", "= It took too long."])
    }

    func testTheSandboxKeepsTheNewestCallsFirst() {
        var sandbox = SheetSandbox()
        let record = { (id: String) in CallLog.Record(spot: "a", arguments: [id], input: nil, frames: [], errors: "", end: .exited(0), started: Date(), seconds: 0) }

        for index in 0..<30 { sandbox.take(call: PlaygroundCall(record: record("c\(index)"), reason: nil)) }

        XCTAssertEqual(sandbox.calls.count, 20)
        XCTAssertEqual(sandbox.calls.first?.lines.first, "$ c29")
    }

    func testThePresetsAreTheRunnableExamplesOfTheGuideAndEachSheetAsASpot() {
        let guide = "# Guide\n\n```sh\n#!/bin/sh\n# title=Hello\nsay hi\n```\n\n```text\nnot run\n```\n\n```js\n// title=Sum\nfunction main() { return '' }\n```\n"

        let presets = SheetSandbox.presets(guide: guide)

        XCTAssertEqual(presets.prefix(2).map(\.name), ["Hello", "Sum"])
        XCTAssertEqual(presets[1].text, "// title=Sum\nfunction main() { return '' }\n")
        XCTAssertEqual(presets.count, 2 + SheetExamples.all.count)
        let sheet = try? XCTUnwrap(presets.last)
        XCTAssertTrue(sheet?.text.hasPrefix("#!/bin/sh\n# title=\(SheetExamples.all.last?.name ?? "")\n# on=sheet.open\ncat <<'SHEET'\n") == true)
    }

    func testAFileOfJavaScriptRunsAsJavaScript() {
        XCTAssertEqual(SheetSandbox.fileExtension(of: "// title=Sum\n"), "js")
        XCTAssertEqual(SheetSandbox.fileExtension(of: "#!/bin/sh\n"), "sh")
    }
}
