import XCTest
@testable import OpenspotCore

/// Proves the one rule of frames: a frame with a block is the whole picture, and a frame of only a head carries
/// effects.
@MainActor
final class SpotRunsFrameTests: SpotRunsCase {
    func testAnActionsFrameWithABlockReplacesTheWholeSheet() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'grid=go\\ngrid=a\\ngrid=b\\n\\nbutton=go\\ntitle=Go\\n\\ntext=a\\ntitle=A\\n\\ntext=b\\ntitle=B\\n' ;;
          go) printf 'text=only\\ntitle=Only\\n' ;;
        esac
        """)
        let sheet = try sheet()
        sheet.open {}
        try await wait("the parts") { sheet.panel?.parts.count == 3 }

        sheet.press(try XCTUnwrap(sheet.panel?.parts.first))

        try await wait("the new picture") { sheet.panel?.parts.map(\.id) == ["only"] }
        try await allEnded()
        try await pause(0.1)
        XCTAssertEqual(log(), ["read", "go"])
    }

    func testALaterFrameOfAReadWithABlockAndNoHeadReplacesAll() async throws {
        try script(header: "read=panel", "printf 'row=a\\ntitle=A\\n---\\n'\nprintf 'text=t\\ntitle=T\\n'")
        let sheet = try sheet()
        runs.panelOpened()
        sheet.open {}

        try await wait("the second picture") { sheet.panel?.parts.map(\.id) == ["t"] && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.list.shown.map(\.run), [])
    }

    func testAFrameOfOnlyAHeadShowsItsToastAndKeepsThePicture() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'row=a\\ntitle=A\\n' ;;
          open) printf 'toast=Saved\\ntitle=Other\\n---\\n'; \(untilRelease) ;;
        esac
        """)
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.pick(try XCTUnwrap(sheet.list.selectedItem))

        try await wait("the toast") { toasts == ["Saved"] }
        XCTAssertEqual(sheet.list.shown.map(\.run), ["a"])
        XCTAssertEqual(sheet.state.title, "Script")
        openGate()
    }

    func testProgressInAHeadShowsOnTheRunningCall() async throws {
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'row=a\\ntitle=A\\n' ;;
          open) printf 'progress=0.4\\ntitle=Copying\\ndetail=2 of 5\\n---\\n'; \(untilRelease) ;;
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
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'row=a\\ntitle=A\\n' ;;
          open) printf 'gauge=g\\nvalue=0.4\\n---\\n'; \(untilRelease) ;;
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
        try script(header: "read=sheet", """
        if [ -f '\(path("second"))' ]; then printf 'toast=Hi\\nsearch=script\\n'; else touch '\(path("second"))'; printf 'row=a\\ntitle=A\\n'; fi
        """)
        let sheet = try sheet()
        var toasts: [String] = []
        sheet.onReport = { if case .toast(let text) = $0 { toasts.append(text) } }
        sheet.open {}
        try await wait("the row") { sheet.list.shown.count == 1 && sheet.calls.isEmpty }

        sheet.read(need: .change)

        try await wait("the empty answer") { sheet.list.shown.isEmpty && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.list.search, .script)
        XCTAssertEqual(toasts, ["Hi"])
    }

    func testAFrameOfAStayingScriptWithABlockReplacesAll() async throws {
        try script(header: "mode=stay", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=read) printf 'end=%s\\n\\nrow=a\\ntitle=A\\n---\\n' "$call" ;;
            arg=open) printf 'toast=Done\\nend=%s\\n---\\n' "$call"; printf 'text=peer\\ntitle=Peer\\n---\\n' ;;
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

    func testAStayingReadThatEndsWithOnlyAHeadKeepsThePictureThatCameBeforeIt() async throws {
        try script(header: "mode=stay", """
        while IFS= read -r line; do
          case "$line" in
            call=*) call=${line#call=} ;;
            arg=read) printf 'row=a\\ntitle=A\\n---\\n'; printf 'end=%s\\n---\\n' "$call" ;;
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
        try script(header: "read=sheet", """
        case "$1" in
          read) printf 'switch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=%s\\n' "$(cat '\(path("a"))' 2>/dev/null || echo false)" "$(cat '\(path("b"))' 2>/dev/null || echo false)" ;;
          a) \(untilRelease); echo "$2" > '\(path("a"))'; printf 'switch=a\\nvalue=%s\\n\\nswitch=b\\nvalue=false\\n' "$2" ;;
          b) echo "$2" > '\(path("b"))'; printf 'switch=a\\nvalue=false\\n\\nswitch=b\\nvalue=%s\\n' "$2" ;;
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

        try await wait("the read after a") { self.log().last == "read" && sheet.calls.isEmpty }
        XCTAssertEqual(sheet.panel?.parts.map(\.value), ["true", "true"])
    }
}
