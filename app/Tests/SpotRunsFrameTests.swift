import XCTest
@testable import OpenspotCore

@MainActor
final class SpotRunsFrameTests: SpotRunsCase {
    func testAnActionsFrameWithABlockReplacesTheWholeSheet() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n' ;;
          go) printf 'frame=\\nclass=gap-part\\n\\ntext=only\\ntitle=Only\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel?.parts.count == 3 }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the new picture") { sheet.panel?.parts.map(\.id) == ["only"] }
        try await allEnded()
        try await wait("the end of the call") { sheet.calls.isEmpty }
        XCTAssertEqual(log(), ["show", "go"])
    }

    func testEachFrameOfAnActThatTurnsTheSheetToRowsShows() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nbutton=go\\ntitle=Go\\n\\ntext=a\\ntitle=A\\n' ;;
          go) printf 'item=x\\ntitle=X\\n---\\n'; \(untilRelease); printf 'item=y\\ntitle=Y\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel?.parts.count == 2 }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))
        try await wait("the first rows") { sheet.list.all.map(\.title) == ["X"] }
        openGate()

        try await wait("the second rows") { sheet.list.all.map(\.title) == ["X", "Y"] }
    }

    func testALaterFrameWithNoRootChangesOnlyTheBlocksItPrintsAndANewIdJoins() async throws {
        try script(toml: "", """
        printf 'frame=\\nclass=grid grid-cols-2 gap-part\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\n'
        printf 'text=b\\ntitle=B2\\n\\ntext=c\\ntitle=C\\nclass=col-span-2\\n'
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the merged picture") { sheet.panel?.parts.map(\.id) == ["a", "b", "c"] && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.panel?.parts.map(\.title), ["A", "B2", "C"])
        XCTAssertEqual(sheet.panel?.tree.children, ["a", "b", "c"])
    }

    func testALaterFrameWithNoRootAddsARowWithANewIdToTheList() async throws {
        try script(toml: "", "printf 'frame=\\n\\nitem=a\\ntitle=A\\n---\\n'\nprintf 'item=b\\ntitle=B\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the two rows") { sheet.list.shown.map(\.run) == ["a", "b"] && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.list.shown.map(\.title), ["A", "B"])
    }

    func testALaterFrameWithARootEmptiesWhatItDoesNotPrint() async throws {
        try script(toml: "", "printf 'frame=\\nclass=gap-part\\n\\nitems=list\\n\\ntext=a\\nparent=list\\ntitle=A\\n\\ntext=a2\\ntitle=A\\n---\\n'\nprintf 'frame=\\nclass=gap-part\\n\\ntext=t\\ntitle=T\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the second picture") { sheet.panel?.parts.map(\.id) == ["t"] && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.list.shown.map(\.run), [])
    }

    func testAFrameOfOnlyARootKeepsThePicture() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'item=a\\ntitle=A\\n' ;;
          press) printf 'frame=\\ntitle=Other\\n---\\n'; \(untilRelease) ;;
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
        try script(toml: "", """
        case "$1" in
          show) printf 'item=a\\ntitle=A\\n' ;;
          press) printf 'frame=\\nprogress=0.4\\ntitle=Copying\\ndetail=2 of 5\\n---\\n'; \(untilRelease) ;;
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

    func testAMainGaugeOfARunningCallIsNoLongerItsProgress() async throws {
        try script(toml: "", """
        case "$1" in
          show) printf 'item=a\\ntitle=A\\n' ;;
          press) printf 'frame=\\nclass=gap-part\\n\\nnumber=g\\nvalue=40\\nmax=100\\n---\\n'; \(untilRelease) ;;
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
        try script(toml: "", """
        if [ -f '\(path("second"))' ]; then printf 'frame=\\nrecents=false\\n'; else touch '\(path("second"))'; printf 'item=a\\ntitle=A\\n'; fi
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.show(need: .change)

        try await wait("the empty answer") { sheet.list.shown.isEmpty && sheet.calls.isEmpty }
        XCTAssertFalse(sheet.spot.keepsRecent)
    }

    func testAFrameOfAStayingScriptWithARootReplacesAll() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=show) printf 'end=%s\\n\\nitem=a\\ntitle=A\\n---\\n' "$call" ;;
            arg=press) printf 'end=%s\\n---\\n' "$call"; printf 'frame=\\nclass=gap-part\\n\\ntext=peer\\ntitle=Peer\\n---\\n' ;;
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
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=}; printf 'call=%s\\n---\\n' "$call" ;;
            arg=show) printf 'frame=\\nclass=gap-part\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n---\\ntext=b\\ntitle=B2\\n---\\nend=%s\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the merged picture") { sheet.panel?.parts.map(\.title) == ["A", "B2"] }
    }

    func testAStayingScriptAddsPointsToItsSeriesWithoutPrintingTheList() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=}; printf 'call=%s\\n---\\n' "$call" ;;
            arg=show) printf 'frame=\\nclass=gap-part\\n\\nseries=cpu\\nvalue=1,2,3\\nkeep=4\\n---\\nseries=cpu\\nadd=4\\n---\\nseries=cpu\\nadd=5,6\\n---\\nend=%s\\n---\\n' "$call" ;;
          esac
        done
        """)
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the points after two adds") { sheet.panel?.parts.first?.number?.points == [3, 4, 5, 6] }
    }

    func testAStayingReadThatEndsWithOnlyAHeadKeepsThePictureThatCameBeforeIt() async throws {
        try script(toml: "stay = true", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=show) printf 'item=a\\ntitle=A\\n---\\n'; printf 'end=%s\\n---\\n' "$call" ;;
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
        try script(toml: "", """
        v=$(sed -n 's/^input\\.value=//p')
        case "$1" in
          show) printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=%s\\n' "$(cat '\(path("a"))' 2>/dev/null || echo false)" "$(cat '\(path("b"))' 2>/dev/null || echo false)" ;;
          a) \(untilRelease); echo "$v" > '\(path("a"))'; printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=false\\n' "$v" ;;
          b) echo "$v" > '\(path("b"))'; printf 'frame=\\nclass=gap-part\\n\\nswitch=a\\nvalue=false\\n\\nswitch=b\\nvalue=%s\\n' "$v" ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel != nil && sheet.calls.isEmpty }
        let parts = try XCTUnwrap(sheet.panel?.parts)

        sheet.set(parts[0], to: "true")
        try await wait("the call of a") { self.log().contains("a") }
        sheet.set(parts[1], to: "true")
        try await wait("the answer of b") { self.log().contains("b") && sheet.calls.count == 1 }
        openGate()

        try await wait("the read after a") { self.log().last == "show" && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.panel?.parts.map(\.value), ["true", "true"])
    }
}
