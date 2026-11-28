import XCTest
@testable import OpenspotCore

@MainActor
final class RouteFormTests: PanelCase {
    private var presses: String {
        folder.appendingPathComponent("presses").path
    }

    private func openAsks() async throws {
        try script("asks", toml: "title = 'Asks'\npages = ['custom']", """
        input=$(cat)
        route=$(printf '%s\\n' "$input" | sed -n 's/^input\\.route=//p')
        case "$1 $route" in
          'show custom') printf 'frame=\\ntype=form\\ntitle=How long\\n\\nfield=minutes\\ntitle=Minutes\\n' ;;
          'show ') printf 'item=custom\\ntitle=Custom\\nroute=custom\\n' ;;
          press*) printf '%s\\n' "$input" | grep '^input\\.' | sort | tr '\\n' ' ' >> '\(presses)' ;;
        esac
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.press("asks")
        try await wait("the open list") { self.model.transition.phase == .open && self.titles == ["Custom"] }
        model.runSelectedItem()
        try await wait("the form page") { self.model.form?.draft.form.title == "How long" }
    }

    func testARouteWhosePagePrintsAFormShowsItAsAPushedPage() async throws {
        try await openAsks()

        XCTAssertEqual(model.flow.current?.route, "custom")
        XCTAssertNotNil(model.flow.behind)
    }

    func testReturnOnAFormPageSendsPressWithItsValuesAndItsRoute() async throws {
        try await openAsks()

        model.setFormValue("45", for: "minutes")
        model.submitForm()

        try await wait("the press") { ((try? String(contentsOfFile: self.presses, encoding: .utf8)) ?? "").contains("input.minutes=45") }
        XCTAssertEqual(try String(contentsOfFile: presses, encoding: .utf8), "input.minutes=45 input.route=custom ")
    }

    func testCancelOnAFormPageGoesBackToTheList() async throws {
        try await openAsks()

        model.cancelForm()

        XCTAssertNil(model.form)
        XCTAssertNil(model.flow.current?.route)
        try await wait("the list") { self.titles == ["Custom"] }
    }
}
