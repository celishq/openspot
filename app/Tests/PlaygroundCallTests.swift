import XCTest
@testable import OpenspotCore

@MainActor
final class PlaygroundCallTests: SpotRunsCase {
    func testTheRunsTellEachCallWithItsPartsAlsoAQuietOne() async throws {
        try script(toml: "on = ['sheet.open', 'sheet.text']", "echo 'slow disk' >&2\nprintf 'text=a\\ntitle=%s\\n' \"$(sed -n 's/^event.value=//p')\"")
        var calls: [PlaygroundCall] = []
        runs.onCall = { calls.append(PlaygroundCall(record: $0, event: $1)) }
        let sheet = try sheet()

        sheet.open(onReady: {})
        try await wait("the read") { calls.count == 1 }
        sheet.search("rep")
        try await wait("the search") { calls.count == 2 }

        XCTAssertEqual(calls[0].lines.dropLast(), ["$ show · event=sheet.open", "> text=a", "> title=", "! slow disk"])
        XCTAssertTrue(calls[0].lines.last?.hasPrefix("= ") == true)
        XCTAssertEqual(calls[1].lines.first, "$ show · event=sheet.text event.value=rep")
        XCTAssertTrue(calls[1].lines.contains("< search=rep"), "\(calls[1].lines)")
    }

    func testTheCallsOfASpotThatUsesTheAccountStayOutOfTheLog() {
        var calls: [PlaygroundCall] = []
        runs.onCall = { calls.append(PlaygroundCall(record: $0, event: $1)) }
        let url = URL(fileURLWithPath: path("account.sh"))

        for uses in [Set<SpotUse>([.account]), []] {
            let spot = Spot(id: "account", name: "Account", url: url, dataName: "account", uses: uses).builtIn()
            runs.record(spot, SpotAction(arguments: ["show"]), input: nil, frames: ["word=secret\n"], errors: "", end: .ended, event: nil, started: Date(), begin: Date())
        }

        XCTAssertEqual(calls.map(\.lines.first), ["$ show"])
    }

    func testTheRunsTellEachCallOfAStayingSpotOnceWhenItEnds() async throws {
        try script(toml: "mode = 'stay'", """
        while IFS= read -r line; do
          case "$line" in
            call=*) id=${line#call=}; name= ;;
            arg=*) [ -n "$name" ] || name=${line#arg=} ;;
            stop=*) name=stop ;;
            '')
              case "$name" in
                stop) ;;
                go) ( while [ ! -f '\(path("done"))' ]; do sleep 0.05; done; printf 'end=%s\\n---\\n' "$id" ) & ;;
                *) printf 'button=go\\ntitle=Go\\nscope=spot\\n\\ntext=a\\ntitle=A\\n\\nend=%s\\n---\\n' "$id" ;;
              esac
              name= ;;
          esac
        done
        """)
        var calls: [PlaygroundCall] = []
        runs.onCall = { calls.append(PlaygroundCall(record: $0, event: $1)) }
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the read") { calls.count == 1 }
        let action = try XCTUnwrap(sheet.spot.actions.first)

        sheet.run(action, item: nil)
        try await wait("the running call") { sheet.calls.count == 1 }
        XCTAssertEqual(calls.count, 1)
        try "".write(toFile: path("done"), atomically: true, encoding: .utf8)
        try await wait("the end of the call") { calls.count == 2 }
        try FileManager.default.removeItem(atPath: path("done"))
        time += 2
        sheet.run(action, item: nil)
        try await wait("the second call") { sheet.calls.count == 1 }
        time += 2
        sheet.run(action, item: nil)
        try "".write(toFile: path("done"), atomically: true, encoding: .utf8)
        try await wait("the end after the stop") { calls.count == 3 }

        XCTAssertEqual(calls[0].lines.first, "$ show · event=sheet.open")
        XCTAssertTrue(calls[0].lines.contains("> button=go"), "\(calls[0].lines)")
        XCTAssertEqual(calls[0].lines.last, "= exit 0")
        XCTAssertEqual(calls[1].lines, ["$ go", "> end=2", "= exit 0"])
        XCTAssertEqual(calls[2].lines, ["$ go", "> end=3", "= exit 0"])
    }

    func testACallPrintsEachArgumentAndHowItEnded() {
        let record = CallLog.Record(spot: "a", arguments: ["move", "row 1", "true"], input: nil, frames: ["toast=Hi\n", "text=t\n"], errors: "", end: .failed("It took too long."), started: Date(), seconds: 1)

        XCTAssertEqual(PlaygroundCall(record: record, event: nil).lines, ["$ move 'row 1' true", "> toast=Hi", "> ---", "> text=t", "= It took too long."])
    }

    func testThePlaygroundKeepsTheNewestCallsFirst() {
        var playground = Playground()
        let record = { (id: String) in CallLog.Record(spot: "a", arguments: [id], input: nil, frames: [], errors: "", end: .exited(0), started: Date(), seconds: 0) }

        for index in 0..<30 { playground.take(call: PlaygroundCall(record: record("c\(index)"), event: nil)) }

        XCTAssertEqual(playground.calls.count, 20)
        XCTAssertEqual(playground.calls.first?.lines.first, "$ c29")
    }

    func testThePresetsAreTheRunnableExamplesOfTheGuideWithTheirManifestAndEachSheetAsASpot() {
        let guide = "# Guide\n\n```toml\ntitle = \"Hello\"\n```\n\n```sh\n#!/bin/sh\nsay hi\n```\n\n```text\nnot run\n```\n\n```sh\nopenspot spot list\n```\n\n```toml\ntitle = \"Sum\"\non = [\"sheet.open\"]\n```\n\n```js\nfunction main() { return '' }\n```\n"

        let presets = Playground.presets(guide: guide)

        XCTAssertEqual(presets.prefix(2).map(\.name), ["Hello", "Sum"])
        XCTAssertEqual(presets[1].manifest, "title = \"Sum\"\non = [\"sheet.open\"]\n")
        XCTAssertEqual(presets[1].text, "function main() { return '' }\n")
        XCTAssertEqual(presets.count, 2 + SheetExamples.all.count)
        let sheet = try? XCTUnwrap(presets.last)
        XCTAssertEqual(sheet?.manifest, "title = \"\(SheetExamples.all.last?.name ?? "")\"\non = [\"sheet.open\"]\n")
        XCTAssertTrue(sheet?.text.hasPrefix("#!/bin/sh\ncat <<'SHEET'\n") == true)
    }

    func testAFileOfJavaScriptRunsAsJavaScript() {
        XCTAssertEqual(Playground.fileExtension(of: "function main() { return '' }\n"), "js")
        XCTAssertEqual(Playground.fileExtension(of: "#!/bin/sh\n"), "sh")
    }
}
