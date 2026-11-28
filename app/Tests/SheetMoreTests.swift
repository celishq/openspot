import XCTest
@testable import OpenspotCore

@MainActor
final class SheetMoreTests: SpotRunsCase {
    private func paged() throws -> SpotRun {
        try script(toml: "[on]\n\"sheet.open\" = true\n\"sheet.text\" = true\n\"sheet.more\" = true", """
        input=$(cat)
        after=$(printf '%s\\n' "$input" | sed -n 's/^input.after=//p')
        words=$(printf '%s\\n' "$input" | sed -n 's/^input.value=//p')
        case "$1:$after" in
          sheet.more:c) printf 'item=d\\ntitle=D %s\\n\\nitem=e\\ntitle=E\\n' "$words" ;;
          sheet.more:*) ;;
          sheet.text:*) printf 'item=a\\ntitle=A %s\\n\\nitem=b\\ntitle=B\\n\\nitem=c\\ntitle=C\\n' "$words" ;;
          *) printf 'item=a\\ntitle=A\\n\\nitem=b\\ntitle=B\\n\\nitem=c\\ntitle=C\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.show(event: .sheet)
        return sheet
    }

    func testMoreAddsTheNextPageAfterTheLastRowAndAnEmptyPageEndsTheList() async throws {
        let sheet = try paged()
        try await wait("the first page") { sheet.list.shown.map(\.run) == ["a", "b", "c"] }

        sheet.more()
        try await wait("the next page") { sheet.list.shown.map(\.run) == ["a", "b", "c", "d", "e"] }
        sheet.more()
        try await wait("the empty page") { sheet.list.isWhole }
        sheet.more()

        try await wait("the end of each call") { !sheet.isShowing && sheet.running(SpotRun.moreKey) == nil }
        XCTAssertEqual(log().filter { $0 == "sheet.more" }.count, 2)
    }

    func testMoreOfASearchCarriesItsWords() async throws {
        let sheet = try paged()
        try await wait("the first page") { sheet.list.shown.count == 3 }
        sheet.search("x")
        try await wait("the searched page") { sheet.list.shown.first?.title == "A x" }

        sheet.more()

        try await wait("the next searched page") { sheet.list.shown.map(\.title) == ["A x", "B", "C", "D x", "E"] }
    }

    func testASheetThatOpensWithTextAsksItsSearchForTheTextAlone() async throws {
        try script(toml: "[on]\n\"sheet.open\" = true\n\"sheet.text\" = true", """
        words=$(sed -n 's/^input.value=//p')
        printf 'item=a\\ntitle=A %s\\n' "$words"
        """)
        let sheet = try sheet()

        sheet.take(query: "x")
        sheet.show(event: .sheet)

        try await wait("the searched rows") { sheet.list.shown.map(\.title) == ["A x"] && !sheet.isShowing }
        XCTAssertEqual(sheet.query, "x")
        XCTAssertEqual(log(), ["sheet.text"])
    }

    func testASpotThatDoesNotDeclareSheetMoreIsNeverAsked() async throws {
        try script(toml: "[on]\n\"sheet.open\" = true", "printf 'item=a\\ntitle=A\\n'")
        let sheet = try sheet()
        sheet.show(event: .sheet)
        try await wait("the rows") { sheet.list.shown.count == 1 }

        sheet.more()

        try await wait("the end of the show") { !sheet.isShowing }
        XCTAssertFalse(log().contains("sheet.more"))
    }
}
