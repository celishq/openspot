import XCTest
@testable import OpenspotCore

@MainActor
final class StayingPickTests: PanelCase {
    private func openHolds() async throws {
        try script("holds", toml: "title = 'Holds'\nstay = true", """
        sheet() { printf 'item=hold\\ntitle=Hold\\n\\nitem=back\\ntitle=Back\\nclose=false\\n'; }
        serve() {
          case "$input" in
            *input.item=hold*) printf '%s\\n---\\ncall=%s\\n---\\nframe=\\ndetail=On\\n---\\n' "$(sheet)" "$call" ;;
            *) printf 'call=%s\\n---\\n%s\\n---\\nend=%s\\n---\\n' "$call" "$(sheet)" "$call" ;;
          esac
        }
        call=
        input=
        while IFS= read -r line; do
          case $line in
            call=*) call=${line#call=}; input= ;;
            '') [ -z "$call" ] || serve; call= ;;
            *) input="$input$line
        " ;;
          esac
        done
        """)
        await model.reload()
        model.isShown = true
        model.panelWillShow()
        model.pushFirst("holds", moving: true)
        try await wait("the open holds") { self.model.openSheetID == "holds" && self.model.transition.phase == .open && self.titles == ["Hold", "Back"] }
    }

    func testAPickWhoseCallKeepsRunningClosesThePanel() async throws {
        try await openHolds()
        let entry = try XCTUnwrap(model.openEntry)
        let hold = try XCTUnwrap(model.openItems?.shown.first { $0.run == "hold" })

        model.pick(hold, of: entry)

        try await wait("the close") { self.host.dismissals == 1 }
    }
}
