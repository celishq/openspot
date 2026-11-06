import XCTest
@testable import OpenspotCore

final class UpdateSpotTests: XCTestCase {
    private actor Presses {
        var checks = 0
        var restarts = 0
        func check() { checks += 1 }
        func restart() { restarts += 1 }
    }

    private actor Work {
        var count = 0
        func set(_ value: Int) { count = value }
    }

    private let presses = Presses()
    private let work = Work()

    private func command(_ spot: UpdateSpot) throws -> PluginCommand {
        let folder = URL(fileURLWithPath: "/tmp")
        return try XCTUnwrap(ShippedSpot.commands(folder: folder, guide: folder, app: "", update: spot).first { $0.name == "Updates" })
    }

    private func spot() -> UpdateSpot {
        let presses = presses
        let work = work
        return UpdateSpot(
            version: "0.2.0",
            runningWork: { await work.count },
            check: { await presses.check() },
            restart: { await presses.restart() }
        )
    }

    func testTheCardShowsTheVersionAndAPressChecks() async throws {
        let command = try command(spot())

        let state = try await command.state(timeout: 5)
        _ = try await command.perform(.run, timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Updates", subtitle: "0.2.0", isOnGrid: false))
        let checks = await presses.checks
        let restarts = await presses.restarts
        XCTAssertEqual(checks, 1)
        XCTAssertEqual(restarts, 0)
    }

    func testAReadyUpdateShowsAndAPressRestarts() async throws {
        let spot = spot()
        await spot.take(ready: "0.3.0")
        let command = try command(spot)

        let state = try await command.state(timeout: 5)
        _ = try await command.perform(.run, timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Restart", subtitle: "Update 0.3.0", isOnGrid: true))
        let checks = await presses.checks
        let restarts = await presses.restarts
        XCTAssertEqual(checks, 0)
        XCTAssertEqual(restarts, 1)
    }

    func testTheSpotIsOffTheGridUntilAnUpdateIsReady() throws {
        XCTAssertFalse(try command(spot()).headerState.isOnGrid)
    }

    func testWithRunningWorkTheFirstPressWarnsAndTheSecondRestarts() async throws {
        let spot = spot()
        await spot.take(ready: "0.3.0")
        await work.set(2)
        let command = try command(spot)

        let warning = try await spot.answer(["run"])
        let warned = try await command.state(timeout: 5)
        let first = await presses.restarts
        _ = try await spot.answer(["run"])
        let second = await presses.restarts

        XCTAssertEqual(warning, "toast=Restarting stops 2 calls. Press again to restart.\n")
        XCTAssertEqual(warned, SpotState(title: "Restart", subtitle: "Stops 2 calls"))
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 1)
    }

    func testOneRunningCallIsNamedInTheSingular() async throws {
        let spot = spot()
        await spot.take(ready: "0.3.0")
        await work.set(1)

        let warning = try await spot.answer(["run"])

        XCTAssertEqual(warning, "toast=Restarting stops 1 call. Press again to restart.\n")
    }

    func testWhenTheWorkChangesAPressWarnsAgain() async throws {
        let spot = spot()
        await spot.take(ready: "0.3.0")
        await work.set(2)
        _ = try await spot.answer(["run"])
        await work.set(1)

        _ = try await spot.answer(["run"])

        let restarts = await presses.restarts
        XCTAssertEqual(restarts, 0)
    }

    func testTheCardFollowsTheOtherShippedSpotsAndHasRoomForItsWords() throws {
        let folder = URL(fileURLWithPath: "/tmp")
        let commands = ShippedSpot.commands(folder: folder, guide: folder, app: "", update: spot())

        XCTAssertEqual(commands.map(\.name), ["Plugins", "Settings", "Updates"])
        XCTAssertEqual(commands.last?.size, .wide)
    }
}
