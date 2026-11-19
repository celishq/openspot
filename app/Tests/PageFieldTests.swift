import XCTest
@testable import OpenspotCore

final class PageFieldTests: PanelCase {
    func testTextTypedOnAPushedPageStaysWhenTheSpotAnswersNothing() async throws {
        let log = try temporaryFolder().appendingPathComponent("calls")
        try script("links", toml: "title = 'Links'\non = ['sheet.open']\npages = ['query:*']", """
        echo "$*" >> '\(log.path)'
        case "$1" in
          show)
            case "$(sed -n 's/^route=//p')" in
              query:*) printf 'frame=query:g\\ngrid=query\\ngrid=go\\n\\nfield=query\\ntitle=Search\\ngrow=false\\n\\nbutton=go\\ntitle=Open\\nlook=strong\\n' ;;
              *) printf 'text=g\\ntitle=Google\\nroute=query:g\\n' ;;
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
        try await wait("the call and the read after it") { ((try? String(contentsOf: log, encoding: .utf8)) ?? "").hasSuffix("query hel\nshow\n") }

        XCTAssertEqual(model.openParts?.parts.map(\.id), ["query", "go"])
        XCTAssertEqual(model.openParts?.parts.first?.value, "hel")
    }
}
