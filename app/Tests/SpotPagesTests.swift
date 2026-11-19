import XCTest
@testable import OpenspotCore

@MainActor
final class SpotPagesTests: SpotRunsCase {
    private func titles(_ sheet: SpotRun) -> [String] {
        sheet.list.shown.map(\.title)
    }

    func testEachReadOfAPageNamesItAndTheFirstSheetNamesNone() async throws {
        try script(toml: "on = ['sheet.open']", "page=$(sed -n 's/^route=//p')\necho \"${page:-none}\" >> '\(path("pages"))'\nprintf 'text=a\\ntitle=Page %s\\n' \"${page:-first}\"")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first sheet") { self.titles(sheet) == ["Page first"] }

        sheet.show(route: "detail")
        try await wait("the page") { self.titles(sheet) == ["Page detail"] }

        XCTAssertEqual(sheet.route, "detail")
        XCTAssertEqual(log("pages"), ["none", "detail"])
    }

    func testAPageThatComesBackShowsItsRowsAtOnceAndReadsAgain() async throws {
        try script(toml: "on = ['sheet.open']", "page=$(sed -n 's/^route=//p')\nprintf 'text=a\\ntitle=Page %s\\n' \"${page:-first}\"")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first sheet") { self.titles(sheet) == ["Page first"] }
        sheet.show(route: "detail")
        try await wait("the page") { self.titles(sheet) == ["Page detail"] }
        try await wait("the end of the read") { !self.runs.isShowing }

        sheet.show(route: nil)

        XCTAssertEqual(titles(sheet), ["Page first"])
        try await wait("the read of the first sheet") { self.log().count == 3 }
    }

    func testAPressOnAPageNamesItToo() async throws {
        try script(toml: "on = ['sheet.open']", "[ \"$1\" = go ] && echo \"$(sed -n 's/^route=//p')\" >> '\(path("pages"))'\nprintf 'button=go\\ntitle=Go\\nscope=spot\\n\\ntext=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        sheet.show(route: "detail")
        try await wait("the page") { !sheet.spot.actions.isEmpty && !self.runs.isShowing }

        sheet.run(try XCTUnwrap(sheet.spot.actions.first), item: nil)

        try await wait("the press") { self.log("pages") == ["detail"] }
    }

    func testAStayingScriptGetsThePageWithEachCall() async throws {
        try script(toml: "mode = 'stay'\non = ['sheet.open']", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in
            call=*) id=${line#call=} ;;
            '') printf 'end=%s\\n\\ntext=a\\ntitle=A\\n---\\n' "$id" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first read") { self.blocks(ids: true).count == 1 }

        sheet.show(route: "detail")

        try await wait("the read of the page") { self.blocks(ids: true).last?.contains("route=detail") == true }
        XCTAssertFalse(blocks(ids: true)[0].contains("route="))
    }

    func testAnInlineScriptGetsThePage() async throws {
        let url = folder.spotFile("script", extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "function main(args, env, input) { return `text=a\\ntitle=Page ${openspot.value('route', input) || 'first'}\\n` }\n".writeInline(to: url, toml: "on = ['sheet.open']")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first sheet") { self.titles(sheet) == ["Page first"] }

        sheet.show(route: "detail")

        try await wait("the page") { self.titles(sheet) == ["Page detail"] }
    }
}
