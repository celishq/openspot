import XCTest
@testable import OpenspotCore

@MainActor
final class SpotPagesTests: SpotRunsCase {
    private func titles(_ sheet: SpotRun) -> [String] {
        sheet.list.shown.map(\.title)
    }

    func testEachReadOfAPageNamesItAndTheFirstSheetNamesNone() async throws {
        try script(header: "on=sheet.open", "echo \"${OPENSPOT_PAGE-none}\" >> '\(path("pages"))'\nprintf 'row=a\\ntitle=Page %s\\n' \"${OPENSPOT_PAGE-first}\"")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first sheet") { self.titles(sheet) == ["Page first"] }

        sheet.show(page: "detail")
        try await wait("the page") { self.titles(sheet) == ["Page detail"] }

        XCTAssertEqual(sheet.page, "detail")
        XCTAssertEqual(log("pages"), ["none", "detail"])
    }

    func test_H2_aPageThatComesBackShowsItsRowsAtOnceAndReadsAgain() async throws {
        try script(header: "on=sheet.open", "printf 'row=a\\ntitle=Page %s\\n' \"${OPENSPOT_PAGE-first}\"")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first sheet") { self.titles(sheet) == ["Page first"] }
        sheet.show(page: "detail")
        try await wait("the page") { self.titles(sheet) == ["Page detail"] }
        try await wait("the end of the read") { !self.runs.isReading }

        sheet.show(page: nil)

        XCTAssertEqual(titles(sheet), ["Page first"])
        try await wait("the read of the first sheet") { self.log().count == 3 }
    }

    func testAPressOnAPageNamesItToo() async throws {
        try script(header: "on=sheet.open", "[ \"$1\" = go ] && echo \"${OPENSPOT_PAGE-none}\" >> '\(path("pages"))'\nprintf 'button=go\\ntitle=Go\\nscope=spot\\n\\nrow=a\\ntitle=A\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        sheet.show(page: "detail")
        try await wait("the page") { !sheet.spot.actions.isEmpty && !self.runs.isReading }

        sheet.run(try XCTUnwrap(sheet.spot.actions.first), item: nil)

        try await wait("the press") { self.log("pages") == ["detail"] }
    }

    func testAStayingScriptGetsThePageWithEachCall() async throws {
        try script(header: "mode=stay\non=sheet.open", """
        while IFS= read -r line; do
          printf '%s\\n' "$line" >> '\(path("blocks"))'
          case "$line" in
            call=*) id=${line#call=} ;;
            '') printf 'end=%s\\n\\nrow=a\\ntitle=A\\n---\\n' "$id" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first read") { self.blocks(ids: true).count == 1 }

        sheet.show(page: "detail")

        try await wait("the read of the page") { self.blocks(ids: true).last?.contains("env.OPENSPOT_PAGE=detail") == true }
        XCTAssertFalse(blocks(ids: true)[0].contains("OPENSPOT_PAGE"))
    }

    func testAnInlineScriptGetsThePage() async throws {
        let url = folder.spotFile("script", extension: "js")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "// on=sheet.open\nfunction main(args, env) { return `row=a\\ntitle=Page ${env.OPENSPOT_PAGE || 'first'}\\n` }\n".write(to: url, atomically: true, encoding: .utf8)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open(onReady: {})
        try await wait("the first sheet") { self.titles(sheet) == ["Page first"] }

        sheet.show(page: "detail")

        try await wait("the page") { self.titles(sheet) == ["Page detail"] }
    }
}
