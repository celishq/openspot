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

    private var front: String? {
        toasts.queue.first(where: \.isShown)?.words
    }

    private func show(_ words: String, kind: ToastKind = .confirm, spot: String = "", press: (@MainActor @Sendable () -> Void)? = nil) async throws {
        toasts.add(kind == .work ? .work(words) : ToastNote(words: words, kind: kind), spot: spot, press: press)
        try await wait("\(words) shows", until: { front == words })
    }

    private func pass(_ seconds: TimeInterval, sleeps: Int, due: TimeInterval? = nil) async throws {
        try await wait("\(sleeps) timers sleep, one due in \(due ?? seconds)", until: { clock.sleepCount == sleeps && clock.isSleeping(for: due ?? seconds) })
        clock.advance(by: seconds)
    }

    private func note(_ blocks: String) throws -> ToastNote {
        try ToastNote(blocks: blocks)
    }

    func testANewToastShowsInPlaceOfTheOthersAndCountsThem() async throws {
        try await show("a")
        XCTAssertEqual(toasts.count, 1)

        try await show("b")

        XCTAssertEqual(toasts.queue.filter(\.isShown).map(\.words), ["b"])
        XCTAssertEqual(toasts.count, 2)
        XCTAssertEqual(window.fronts, 2)
    }

    func testTheNextToastStepsInWhenTheShownOneLeaves() async throws {
        try await show("a")
        try await show("b")

        toasts.press(try XCTUnwrap(toasts.queue.first).id)

        XCTAssertEqual(front, "a")
        XCTAssertEqual(toasts.count, 1)
    }

    func testTheWindowFitsTheBarsOnlyWhenMoreThanOneToastWaits() async throws {
        try await show("a")
        XCTAssertEqual(toasts.height, 40)

        try await show("b")

        XCTAssertEqual(toasts.height, 40 + SpotTokens.toastBarsGap + SpotTokens.toastBarHeight)
    }

    func testAFourthToastDropsTheOldest() async throws {
        for words in ["a", "b", "c", "d"] { try await show(words) }

        XCTAssertEqual(front, "d")
        XCTAssertEqual(toasts.count, 3)
        try await pass(MotionTokens.fadeOut, sleeps: 2, due: MotionTokens.fadeOut)
        try await wait("the oldest leaves", until: { toasts.queue.map(\.words) == ["d", "c", "b"] })
    }

    func testAWorkToastGivesWayToTheNextToastOfItsSpot() async throws {
        try await show("working", kind: .work)
        try await show("other", spot: "a")

        try await show("done")

        XCTAssertEqual(front, "done")
        XCTAssertEqual(toasts.count, 2)
    }

    func testAnIdChangesAWaitingToastInPlace() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\n"), spot: "s")
        try await wait("the upload shows", until: { front == "Uploading" })
        try await show("other")
        try await pass(4, sleeps: 1, due: 5)

        toasts.add(try note("toast=up\ntitle=Uploaded\n"), spot: "s")

        XCTAssertEqual(toasts.queue.map(\.words), ["other", "Uploaded"])
        try await pass(1, sleeps: 1, due: 1)
        try await wait("the upload steps in", until: { front == "Uploaded" })
        try await pass(5, sleeps: 2, due: 5)
        try await wait("the upload ends", until: { front == nil })
    }

    func testAnIdRestartsTheTimeOfTheShownToast() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\n"), spot: "s")
        try await wait("the upload shows", until: { front == "Uploading" })
        try await pass(4, sleeps: 1, due: 5)

        toasts.add(try note("toast=up\ntitle=Uploaded\n"), spot: "s")

        try await wait("its time starts again", until: { clock.sleepCount == 1 && clock.isSleeping(for: 5) })
    }

    func testAWaitingToastsTimeStartsWhenItShows() async throws {
        try await show("a")
        try await pass(3, sleeps: 1, due: 5)
        try await show("b")
        try await wait("only the shown toast's time runs", until: { clock.sleepCount == 1 && clock.isSleeping(for: 5) })

        clock.advance(by: 5)

        try await wait("a steps in", until: { front == "a" })
        try await wait("a has its whole time", until: { clock.isSleeping(for: 5) })
    }

    func testTheSameIdOfAnotherSpotIsAnotherToast() async throws {
        toasts.add(try note("toast=up\ntitle=A\n"), spot: "a")
        toasts.add(try note("toast=up\ntitle=B\n"), spot: "b")

        try await wait("both wait", until: { front == "B" && toasts.count == 2 })
    }

    func testDropTakesTheToastOfTheIdAway() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\nkeep=true\n"), spot: "s")
        try await wait("the upload shows", until: { front == "Uploading" })

        toasts.drop("up", of: "s")

        XCTAssertNil(front)
    }

    func testAnIdShownAgainWhileItsToastLeavesShowsOneToast() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\nkeep=true\n"), spot: "s")
        try await wait("the upload shows", until: { front == "Uploading" })
        toasts.drop("up", of: "s")

        toasts.add(try note("toast=up\ntitle=Uploaded\nkeep=true\n"), spot: "s")
        try await wait("the new upload shows", until: { front == "Uploaded" })
        try await pass(MotionTokens.fadeOut, sleeps: 1)

        try await wait("one toast stays", until: { toasts.queue.map(\.words) == ["Uploaded"] })
        XCTAssertEqual(toasts.count, 1)
        toasts.drop("up", of: "s")
        XCTAssertNil(front)
    }

    func testAKeptToastNeverExpires() async throws {
        toasts.add(try note("toast=up\ntitle=Uploading\nkeep=true\n"), spot: "s")
        try await wait("the upload shows", until: { front == "Uploading" })
        try await show("working", kind: .work)
        try await show("brief", spot: "b")

        try await pass(60, sleeps: 1, due: 5)

        try await wait("the brief toast ends", until: { front == "working" && toasts.count == 2 })
    }

    func testHoverHoldsEveryTimerAndExpiryResumesAfter() async throws {
        try await show("a")
        try await show("b")

        toasts.hold(true)
        try await wait("no timer sleeps", until: { clock.sleepCount == 0 })
        clock.advance(by: 60)
        XCTAssertEqual(toasts.count, 2)

        toasts.hold(false)
        try await pass(4, sleeps: 1, due: 5)
        XCTAssertEqual(toasts.count, 2)
        try await pass(1, sleeps: 1, due: 1)
        try await wait("the next steps in", until: { front == "a" })
    }

    func testAPressRunsWhatItDoesAndClosesTheToast() async throws {
        var runs = 0
        try await show("a", press: { runs += 1 })
        let toast = try XCTUnwrap(toasts.queue.first)

        toasts.press(toast.id)

        XCTAssertEqual(runs, 1)
        XCTAssertNil(front)
        try await pass(MotionTokens.fadeOut, sleeps: 1)
        try await wait("the window goes away", until: { window.putAways == 1 })
        XCTAssertEqual(toasts.queue.count, 0)
    }

    func testTheLeadFollowsTheNewestShownToast() async throws {
        try await show("saved")
        XCTAssertEqual(toasts.leadKind, .confirm)
        try await show("failed", kind: .failure)
        XCTAssertEqual(toasts.leadKind, .failure)

        toasts.press(try XCTUnwrap(toasts.queue.first).id)

        XCTAssertEqual(toasts.leadKind, .confirm)
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
        XCTAssertEqual(toasts.queue.first?.words, "second Press `\(key.label)` to fix it.")

        window.fixPress?()
        window.fixPress?()

        XCTAssertEqual(fixes, ["second", "first"])
    }

    func testEachTimerOfAToastSleepsWithATolerance() async throws {
        try await show("Saved")

        XCTAssertFalse(clock.tolerances.isEmpty)
        XCTAssertFalse(clock.tolerances.contains(nil))
    }

    func testAToastThatCoversAFailureTakesItsFixKeyUntilItLeaves() async throws {
        let key = try XCTUnwrap(Shortcut(text: "cmd+shift+f"))
        var fixes = 0
        toasts.add(.failure("failed"), press: { fixes += 1 }, fixKey: key)
        try await wait("the failure shows", until: { front?.hasPrefix("failed") == true })
        XCTAssertNotNil(window.fixPress)

        try await show("ok")
        XCTAssertNil(window.fixPress)

        toasts.press(try XCTUnwrap(toasts.queue.first).id)
        try await wait("the failure steps in with its key", until: { window.fixPress != nil })
        window.fixPress?()
        XCTAssertEqual(fixes, 1)
    }
}
