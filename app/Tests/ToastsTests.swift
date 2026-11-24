import XCTest
@testable import OpenspotCore

@MainActor
final class ToastsTests: XCTestCase {
    private var clock: FakeClock!
    private var host: FakeHost!
    private var window: FakeToastWindow!
    private var toasts: Toasts!

    override func setUp() async throws {
        clock = FakeClock()
        host = FakeHost()
        window = FakeToastWindow()
        toasts = Toasts(host: host, clock: clock.value)
        toasts.window = window
    }

    private var visible: [String] {
        toasts.shown.filter(\.isShown).map(\.words)
    }

    private func show(_ words: String, kind: ToastKind = .confirm, spot: String = "", press: (@MainActor @Sendable () -> Void)? = nil) async throws {
        toasts.add(ToastNote(words: words, kind: kind), spot: spot, press: press)
        try await wait("\(words) shows", until: { visible.first == words })
    }

    private func pass(_ seconds: TimeInterval, sleeps: Int, due: TimeInterval? = nil) async throws {
        try await wait("\(sleeps) timers sleep, one due in \(due ?? seconds)", until: { clock.sleepCount == sleeps && clock.isSleeping(for: due ?? seconds) })
        clock.advance(by: seconds)
    }

    private func note(_ blocks: String) throws -> ToastNote {
        try ToastNote(blocks: blocks)
    }

    func testANewToastGoesOnTopOfTheOthers() async throws {
        try await show("a")
        try await show("b")

        XCTAssertEqual(visible, ["b", "a"])
        XCTAssertEqual(window.fronts, 2)
    }

    func testAFourthToastDropsTheOldest() async throws {
        for words in ["a", "b", "c", "d"] { try await show(words) }

        XCTAssertEqual(visible, ["d", "c", "b"])
        try await pass(MotionTokens.fadeOut, sleeps: 4)
        try await wait("the oldest leaves", until: { toasts.shown.map(\.words) == ["d", "c", "b"] })
    }

    func testAWorkToastGivesWayToTheNextToastOfItsSpot() async throws {
        try await show("working", kind: .work)
        try await show("other", spot: "a")

        try await show("done")

        XCTAssertEqual(visible, ["done", "other"])
    }

    func testAnIdChangesItsToastInPlaceAndRestartsItsTime() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\n"), spot: "s")
        try await wait("the upload shows", until: { visible == ["Uploading"] })
        try await show("other")
        try await pass(4, sleeps: 2, due: 5)

        toasts.add(try note("toast=up\ntitle=Uploaded\n"), spot: "s")

        XCTAssertEqual(toasts.shown.map(\.words), ["other", "Uploaded"])
        try await pass(4, sleeps: 2, due: 5)
        try await wait("the other toast ends", until: { visible == ["Uploaded"] })
        try await pass(2, sleeps: 2, due: 1)
        try await wait("the upload ends", until: { visible.isEmpty })
    }

    func testTheSameIdOfAnotherSpotIsAnotherToast() async throws {
        toasts.add(try note("toast=up\ntitle=A\n"), spot: "a")
        toasts.add(try note("toast=up\ntitle=B\n"), spot: "b")

        try await wait("both show", until: { visible == ["B", "A"] })
    }

    func testDropTakesTheToastOfTheIdAway() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\nkeep=true\n"), spot: "s")
        try await wait("the upload shows", until: { visible == ["Uploading"] })

        toasts.drop("up", of: "s")

        XCTAssertEqual(visible, [])
    }

    func testAnIdShownAgainWhileItsToastLeavesShowsOneToast() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\nkeep=true\n"), spot: "s")
        try await wait("the upload shows", until: { visible == ["Uploading"] })
        toasts.drop("up", of: "s")

        toasts.add(try note("toast=up\ntitle=Uploaded\nkeep=true\n"), spot: "s")
        try await wait("the new upload shows", until: { visible == ["Uploaded"] })
        try await pass(MotionTokens.fadeOut, sleeps: 1)

        try await wait("one toast stays", until: { toasts.shown.map(\.words) == ["Uploaded"] })
        XCTAssertEqual(toasts.places.count, 1)
        toasts.drop("up", of: "s")
        XCTAssertEqual(visible, [])
    }

    func testAKeptToastNeverExpires() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\nkeep=true\n"), spot: "s")
        try await wait("the upload shows", until: { visible == ["Uploading"] })
        try await show("working", kind: .work)
        try await show("brief", spot: "b")

        try await pass(60, sleeps: 1, due: 5)

        try await wait("the brief toast ends", until: { visible == ["working", "Uploading"] })
    }

    func testHoverHoldsEveryTimerAndExpiryResumesAfter() async throws {
        try await show("a")
        try await show("b")

        toasts.hold(true)
        XCTAssertTrue(toasts.isExpanded)
        try await wait("no timer sleeps", until: { clock.sleepCount == 0 })
        clock.advance(by: 60)
        XCTAssertEqual(visible, ["b", "a"])

        toasts.hold(false)
        XCTAssertFalse(toasts.isExpanded)
        try await pass(4, sleeps: 3, due: 5)
        XCTAssertEqual(visible, ["b", "a"])
        try await pass(1, sleeps: 2, due: 1)
        try await wait("both end", until: { visible.isEmpty })
    }

    func testHoverExpandsTheStack() async throws {
        try await show("a")
        try await show("b")
        let collapsed = toasts.places

        toasts.hold(true)

        XCTAssertNotEqual(toasts.places, collapsed)
        XCTAssertEqual(toasts.places, Dictionary(uniqueKeysWithValues: zip(toasts.shown.map(\.id), ToastLayout(heights: [40, 40], isExpanded: true).places)))
    }

    func testAPressRunsWhatItDoesAndClosesTheToast() async throws {
        var runs = 0
        try await show("a", press: { runs += 1 })
        let toast = try XCTUnwrap(toasts.shown.first)

        toasts.press(toast.id)

        XCTAssertEqual(runs, 1)
        XCTAssertEqual(visible, [])
        try await pass(MotionTokens.fadeOut, sleeps: 1)
        try await pass(MotionTokens.move, sleeps: 1)
        try await wait("the window goes away", until: { window.putAways == 1 })
        XCTAssertEqual(toasts.shown.count, 0)
    }

    func testTheLeadFollowsTheNewestShownToast() async throws {
        try await show("saved")
        XCTAssertEqual(toasts.lead, .confirm)
        try await show("failed", kind: .failure)
        XCTAssertEqual(toasts.lead, .failure)

        toasts.press(try XCTUnwrap(toasts.shown.first).id)

        XCTAssertEqual(toasts.lead, .confirm)
    }

    func testTheWidthIsTheWidestToast() async throws {
        try await show("a")
        try await show("longer words")

        XCTAssertEqual(toasts.width, 100 + CGFloat("longer words".count))
    }

    func testTheFixKeyPassesToTheNewestToastWithAFix() async throws {
        let key = try XCTUnwrap(Shortcut(text: "cmd+shift+f"))
        var fixes: [String] = []
        toasts.add(.failure("first"), press: { fixes.append("first") }, fixKey: key)
        toasts.add(.failure("second"), press: { fixes.append("second") }, fixKey: key)
        XCTAssertEqual(toasts.shown.first?.words, "second Press `\(key.label)` to fix it.")

        window.fixPress?()
        window.fixPress?()

        XCTAssertEqual(fixes, ["second", "first"])
    }
}
