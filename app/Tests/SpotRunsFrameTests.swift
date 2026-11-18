import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsFrameTests: SpotRunsCase {
    func testAnActionsFrameWithABlockReplacesTheWholeSheet() async throws {
        try script(toml: "on = ['sheet.open']", """
        case "$1" in
          show) printf 'frame=\\ngrid=go\\ngrid=a\\ngrid=b\\n\\nbutton=go\\ntitle=Go\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n' ;;
          go) printf 'frame=\\ngrid=only\\n\\ntext=only\\ntitle=Only\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel?.parts.count == 3 }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the new picture") { sheet.panel?.parts.map(\.id) == ["only"] }
        try await allEnded()
        try await pause(0.1)
        XCTAssertEqual(log(), ["show", "go"])
    }

    func testALaterFrameWithNoRootChangesOnlyTheBlocksItPrintsAndANewIdJoins() async throws {
        try script(toml: "on = ['sheet.open']", """
        printf 'frame=\\ngrid=a b\\ngrid=c c\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\n'
        printf 'text=b\\ntitle=B2\\n\\ntext=c\\ntitle=C\\n'
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the merged picture") { sheet.panel?.parts.map(\.id) == ["a", "b", "c"] && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.panel?.parts.map(\.title), ["A", "B2", "C"])
        XCTAssertEqual(sheet.panel?.layout?.areas.keys.sorted(), ["a", "b", "c"])
    }

    func testALaterFrameWithNoRootAddsARowWithANewIdToTheList() async throws {
        try script(toml: "on = ['sheet.open']", "printf 'frame=\\n\\ntext=a\\ntitle=A\\n---\\n'\nprintf 'text=b\\ntitle=B\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the two rows") { sheet.list.shown.map(\.run) == ["a", "b"] && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.list.shown.map(\.title), ["A", "B"])
    }

    func testALaterFrameWithARootEmptiesWhatItDoesNotPrint() async throws {
        try script(toml: "on = ['sheet.open']", "printf 'frame=\\ngrid=a2\\n\\ntext=a\\ntitle=A\\n\\ntext=a2\\ntitle=A\\n---\\n'\nprintf 'frame=\\ngrid=t\\n\\ntext=t\\ntitle=T\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the second picture") { sheet.panel?.parts.map(\.id) == ["t"] && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.list.shown.map(\.run), [])
    }

    func testAFrameOfOnlyARootKeepsThePicture() async throws {
        try script(toml: "on = ['sheet.open']", """
        case "$1" in
          show) printf 'text=a\\ntitle=A\\n' ;;
          open) printf 'frame=\\ntitle=Other\\n---\\n'; \(untilRelease) ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the running call") { sheet.calls.first?.title == "Other" }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
        XCTAssertEqual(sheet.state.title, "Script")
        openGate()
    }

    func testProgressInAHeadShowsOnTheRunningCall() async throws {
        try script(toml: "on = ['sheet.open']", """
        case "$1" in
          show) printf 'text=a\\ntitle=A\\n' ;;
          open) printf 'frame=\\nprogress=0.4\\ntitle=Copying\\ndetail=2 of 5\\n---\\n'; \(untilRelease) ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the progress") { sheet.calls.first?.fill == 0.4 }
        XCTAssertEqual(sheet.calls.first?.title, "Copying")
        XCTAssertEqual(sheet.calls.first?.detail, "2 of 5")
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
        openGate()
    }

    func testATerminalCodeShowsProgressOnTheRunningCallAndANotificationAsAToast() async throws {
        try script(toml: "on = ['sheet.open']", """
        case "$1" in
          show) printf 'text=a\\ntitle=A\\n' ;;
          open) printf '\\033]9;Copied\\007\\033]9;4;1;40\\007'; \(untilRelease) ;;
        esac
        """)
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the progress and the toast") { sheet.calls.first?.fill == 0.4 && toasts == ["Copied"] }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
        openGate()
    }

    func testAMainGaugeOfARunningCallIsNoLongerItsProgress() async throws {
        try script(toml: "on = ['sheet.open']", """
        case "$1" in
          show) printf 'text=a\\ntitle=A\\n' ;;
          open) printf 'frame=\\ngrid=g\\n\\ngraph=g\\nvalue=0.4\\n---\\n'; \(untilRelease) ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the gauge") { sheet.panel?.parts.map(\.id) == ["g"] }
        XCTAssertNil(sheet.calls.first?.fill)
        openGate()
    }

    func testAReadThatEndsWithOnlyAHeadShowsNothingAndKeepsItsHead() async throws {
        try script(toml: "on = ['sheet.open']", """
        if [ -f '\(path("second"))' ]; then printf 'frame=\\nrecents=false\\n'; else touch '\(path("second"))'; printf 'text=a\\ntitle=A\\n'; fi
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.read(need: .change)

        try await wait("the empty answer") { sheet.list.shown.isEmpty && sheet.calls.isEmpty }
        XCTAssertFalse(sheet.spot.keepsRecent)
    }

    func testAFrameOfAStayingScriptWithARootReplacesAll() async throws {
        try script(toml: "mode = 'stay'", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=show) printf 'end=%s\\n\\ntext=a\\ntitle=A\\n---\\n' "$call" ;;
            arg=open) printf 'end=%s\\n---\\n' "$call"; printf 'frame=\\ngrid=peer\\n\\ntext=peer\\ntitle=Peer\\n---\\n' ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the peer picture") { sheet.panel?.parts.map(\.id) == ["peer"] }
        XCTAssertEqual(sheet.list.shown.map(\.run), [])
    }

    func testALaterFrameOfAStayingScriptWithNoRootMergesIntoTheFrameOfItsCall() async throws {
        try script(toml: "mode = 'stay'", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=}; printf 'call=%s\\n---\\n' "$call" ;;
            arg=show) printf 'frame=\\ngrid=a\\ngrid=b\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\ntext=b\\ntitle=B2\\n---\\nend=%s\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the merged picture") { sheet.panel?.parts.map(\.title) == ["A", "B2"] }
    }

    func testAStayingReadThatEndsWithOnlyAHeadKeepsThePictureThatCameBeforeIt() async throws {
        try script(toml: "mode = 'stay'", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=show) printf 'text=a\\ntitle=A\\n---\\n'; printf 'end=%s\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        var isReady = false
        runs.panelOpened()

        sheet.open { isReady = true }

        try await wait("the answer") { isReady }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
    }

    func testAnOutdatedAnswerChangesNothingAndAReadFollowsItsEnd() async throws {
        try script(toml: "on = ['sheet.open']", """
        case "$1" in
          show) printf 'frame=\\ngrid=a\\ngrid=b\\n\\nswitch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=%s\\n' "$(cat '\(path("a"))' 2>/dev/null || echo false)" "$(cat '\(path("b"))' 2>/dev/null || echo false)" ;;
          a) \(untilRelease); echo "$2" > '\(path("a"))'; printf 'frame=\\ngrid=a\\ngrid=b\\n\\nswitch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=false\\n' "$2" ;;
          b) echo "$2" > '\(path("b"))'; printf 'frame=\\ngrid=a\\ngrid=b\\n\\nswitch=a\\nvalue=false\\n\\nswitch=b\\nvalue=%s\\n' "$2" ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil && sheet.calls.isEmpty }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[0], to: "true")
        try await wait("the call of a") { self.log().contains("a true") }
        sheet.set(parts[1], to: "true")
        try await wait("the answer of b") { self.log().contains("b true") && sheet.calls.count == 1 }
        openGate()

        try await wait("the read after a") { self.log().last == "show" && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.panel?.parts.map(\.value), ["true", "true"])
    }
}
