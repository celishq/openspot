import XCTest
@testable import OpenspotCore

/// Proves the Updates spot of the app: search finds it with the version, and the grid shows it with a downloaded update.
/// A press checks now or restarts into the update, and it warns once before a restart that would stop running calls.
final class UpdateSpotTests: BuiltInCase {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    func testAReadStartsOneOpenspotAndNoJq() async throws {
        let programs = try countPrograms()

        _ = try await spot("updates").state(timeout: 5)

        XCTAssertEqual(programs(), ["openspot app status --frame"])
    }

    func testTheCardShowsTheVersionAndAPressChecks() async throws {
        let spot = try spot("updates")

        let state = try await spot.state(timeout: 5)
        _ = try await spot.perform(.open, timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Updates", subtitle: version, isOnGrid: false))
        let checks = await app.checks
        let installs = await app.installs
        XCTAssertEqual(checks, 1)
        XCTAssertEqual(installs, 0)
    }

    func testAReadyUpdateShowsAndAPressRestarts() async throws {
        await app.set(update: "0.3.0", calls: 0)
        let spot = try spot("updates")

        let state = try await spot.state(timeout: 5)
        _ = try await spot.perform(.open, timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Restart", subtitle: "Update 0.3.0", isOnGrid: true))
        let checks = await app.checks
        let installs = await app.installs
        XCTAssertEqual(checks, 0)
        XCTAssertEqual(installs, 1)
    }

    func testItReadsWhenTheAppHasAnUpdate() throws {
        let spot = try spot("updates")

        XCTAssertTrue(spot.read?.has(.event(SpotEvent.appUpdate)) == true)
        XCTAssertTrue(spot.read?.has(.panel) == true)
        XCTAssertTrue(spot.isBuiltIn)
    }

    func testWithRunningWorkTheFirstPressWarnsAndTheSecondRestarts() async throws {
        await app.set(update: "0.3.0", calls: 2)
        let spot = try spot("updates")

        let warning = try await spot.perform(.open, timeout: 5)
        let warned = try await spot.state(timeout: 5)
        let first = await app.installs
        _ = try await spot.perform(.open, timeout: 5)
        let second = await app.installs

        XCTAssertEqual(warning, "Restarting stops 2 calls. Press again to restart.")
        XCTAssertEqual(warned, SpotState(title: "Restart", subtitle: "Stops 2 calls"))
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 1)
    }

    func testOneRunningCallIsNamedInTheSingular() async throws {
        await app.set(update: "0.3.0", calls: 1)

        let warning = try await spot("updates").perform(.open, timeout: 5)

        XCTAssertEqual(warning, "Restarting stops 1 call. Press again to restart.")
    }

    func testWhenTheWorkChangesAPressWarnsAgain() async throws {
        let spot = try spot("updates")
        await app.set(update: "0.3.0", calls: 2)
        _ = try await spot.perform(.open, timeout: 5)
        await app.set(update: "0.3.0", calls: 1)

        _ = try await spot.perform(.open, timeout: 5)

        let installs = await app.installs
        XCTAssertEqual(installs, 0)
    }

    func testAWarningEndsWithItsUpdate() async throws {
        let spot = try spot("updates")
        await app.set(update: "0.3.0", calls: 2)
        _ = try await spot.perform(.open, timeout: 5)
        await app.set(update: nil, calls: 2)
        _ = try await spot.state(timeout: 5)
        await app.set(update: "0.4.0", calls: 2)

        let warning = try await spot.perform(.open, timeout: 5)

        XCTAssertEqual(warning, "Restarting stops 2 calls. Press again to restart.")
        let installs = await app.installs
        XCTAssertEqual(installs, 0)
    }
}
