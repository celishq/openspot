import XCTest
@testable import OpenspotCore

final class PageFieldTests: PanelCase {
    func testTextTypedOnAPushedPageStaysWhenTheSpotAnswersNothing() async throws {
        let log = try temporaryFolder().appendingPathComponent("calls")
        try script("links", toml: "title = 'Links'\npages = ['query:*']\n[on]\n\"sheet.open\" = true", """
        echo "$*" >> '\(log.path)'
        case "$1" in
          show)
            case "$(sed -n 's/^input.route=//p')" in
              query:*) printf 'frame=query:g\\nclass=gap-part\\n\\nfield=query\\ntitle=Search\\n\\nbutton=go\\ntitle=Open\\nclass=bg-accent\\n' ;;
              *) printf 'item=g\\ntitle=Google\\nroute=query:g\\n' ;;
            esac
            ;;
        esac
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("links")
        try await wait("the list") { self.titles == ["Google"] }
        model.runItem(try XCTUnwrap(model.openItems?.shown.first))
        try await wait("the page") { self.model.openParts?.parts.first?.id == "query" }
        let field = try XCTUnwrap(model.openParts?.parts.first)

        model.setPart(field, to: "hel")
        try await wait("the call and the read after it") { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").hasSuffix("query\nshow\n") }

        XCTAssertEqual(model.openParts?.parts.map(\.id), ["query", "go"])
        XCTAssertEqual(model.openParts?.parts.first?.value, "hel")
    }
}
