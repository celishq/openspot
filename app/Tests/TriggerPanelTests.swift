import XCTest
@testable import OpenspotCore

final class TriggerPanelTests: PanelCase {
    private func writeSnooze(answer: String = "") throws {
        try script("snooze", toml: "title = 'Snooze'\n[on]\ncommand = ['snooze', 'later']", """
        echo "$1" >> '\(folder.appendingPathComponent("calls").path)'
        case "$1" in
          show) printf 'text=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\nclose=false\\n' ;;
          command|press) printf '\(answer)' ;;
        esac
        """)
    }

    private func open() async {
        await model.reload()
        model.isShown = true
        model.panelWillShow()
    }

    private func type(_ query: String) {
        model.query = query
        model.landSearch()
    }

    private func openSheet() async throws {
        await open()
        model.press("snooze")
        try await wait("the rows") { self.titles == ["A", "B"] && self.model.transition.phase == .open }
    }

    func testEachCommandWordIsASlashCommandOfTheSpot() async throws {
        try writeSnooze()
        await open()

        type("/later tomorrow")

        XCTAssertEqual(model.visible.map(\.state.title), ["later"])
        XCTAssertEqual(model.hint, "⏎ later \"tomorrow\"")
    }

    func testACommandThatReturnsNothingClosesThePanel() async throws {
        try writeSnooze()
        await open()

        type("/later")
        model.runSelected()

        try await wait("the close") { self.host.dismissals == 1 }
    }

    func testACommandThatReturnsAViewShowsItInItsSheet() async throws {
        try writeSnooze(answer: "frame=\\n\\ntext=done\\ntitle=Snoozed\\n")
        await open()

        type("/snooze tomorrow")
        model.runSelected()

        try await wait("the sheet") { self.model.openSheetID == "snooze" }
        XCTAssertEqual(host.dismissals, 0)
    }

    func testAPressThatReturnsNothingClosesThePanelUnlessTheItemSaysCloseFalse() async throws {
        try writeSnooze()
        try await openSheet()

        model.runSelectedItem()
        try await wait("the close") { self.host.dismissals == 1 }

        model.isShown = true
        model.panelWillShow()
        model.press("snooze")
        try await wait("the rows") { self.titles == ["A", "B"] }
        model.sheets["snooze"]?.list.select(run: "b")
        model.runSelectedItem()
        try await pressEnded(2)
        XCTAssertEqual(host.dismissals, 1)
    }

    func testAPressThatReturnsAViewKeepsThePanel() async throws {
        try writeSnooze(answer: "frame=\\n\\ntext=done\\ntitle=Picked\\n")
        try await openSheet()

        model.runSelectedItem()

        try await pressEnded(1)
        XCTAssertEqual(host.dismissals, 0)
    }

    private func pressEnded(_ count: Int) async throws {
        let file = folder.appendingPathComponent("calls")
        try await wait("the end of the press") {
            let calls = ((try? String(contentsOf: file, encoding: .utf8)) ?? "").split(separator: "\n")
            return calls.filter { $0 == "press" }.count == count && self.model.sheets["snooze"]?.calls.isEmpty == true
        }
    }
}
