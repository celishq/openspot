import XCTest
@testable import OpenspotCore

@MainActor
final class ViewVariantRunTests: SpotRunsCase {
    func testAPressOnACardThatShowsOnlyOneSwitchChangesThatSwitch() async throws {
        try script(toml: "[on]\n'panel.open' = true", """
        . "$OPENSPOT_SH"
        [ "$1" = power ] && echo "$(value value)" > '\(path("power"))'
        [ "$1" = show ] && printf 'frame=\\nclass=gap-2\\n\\ntext=label\\ntitle=Lamp\\nclass=card:hidden\\n\\nswitch=power\\nvalue=%s\\n' "$(cat '\(path("power"))' 2>/dev/null || echo false)"
        exit 0
        """)
        let sheet = try sheet()
        runs.panelOpened()
        try await wait("the kind") { sheet.spot.kind == .toggle }

        sheet.pressCard()

        try await wait("the call") { self.log().starts(with: ["show", "power"]) && self.log("power") == ["true"] }
        try await wait("the switch shows on after the show it asks again") { self.log().count >= 3 && sheet.state.on == true }
    }

    func testTheMenuBarReadsTheValueThatShowsOnTheBar() async throws {
        try script(toml: "[on]\n'panel.open' = true", """
        [ "$1" = show ] && printf 'frame=\\nclass=gap-2\\n\\ntext=time\\ntitle=14:20\\nclass=hidden bar:flex\\n\\ntext=date\\ntitle=Sunday\\n'
        exit 0
        """)
        let sheet = try sheet()
        runs.panelOpened()

        try await wait("the value of the bar") { sheet.reading.value?.title == "14:20" }
        XCTAssertTrue(sheet.reading.hasBar)
    }
}
