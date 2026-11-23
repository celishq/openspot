import XCTest
@testable import OpenspotCore

final class UpdateSpotTests: BuiltInCase {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    func testAReadStartsOneOpenspotAndNoJq() async throws {
        let programs = try countPrograms()

        _ = try await spot("updates").state(timeout: 60)

        XCTAssertEqual(programs(), ["openspot app status"])
    }

    func testTheCardShowsTheVersionAndAPressChecks() async throws {
        let spot = try spot("updates")

        let state = try await spot.state(timeout: 60)
        _ = try await spot.perform("update", timeout: 60)

        XCTAssertEqual(state, SpotState(title: "Updates", subtitle: version, isOnGrid: false))
        let checks = await app.checks
        let installs = await app.installs
        XCTAssertEqual(checks, 1)
        XCTAssertEqual(installs, 0)
    }

    func testAReadyUpdateShowsAndAPressRestarts() async throws {
        await app.set(update: "0.3.0", calls: 0)
        let spot = try spot("updates")

        let state = try await spot.state(timeout: 60)
        _ = try await spot.perform("update", timeout: 60)

        XCTAssertEqual(state, SpotState(title: "Restart", subtitle: "Update 0.3.0", isOnGrid: true))
        let checks = await app.checks
        let installs = await app.installs
        XCTAssertEqual(checks, 0)
        XCTAssertEqual(installs, 1)
    }

    func testItReadsAtLaunchAndWhenTheAppHasAnUpdateAndNotAtEachPanelOpen() throws {
        let spot = try spot("updates")

        XCTAssertTrue(spot.triggers.has(.event(SpotEvent.appUpdate)))
        XCTAssertTrue(spot.triggers.has(.event(SpotEvent.appLaunch)))
        XCTAssertFalse(spot.triggers.has(.panel))
        XCTAssertTrue(spot.showsState)
        XCTAssertTrue(spot.isBuiltIn)
    }

    func testWithRunningWorkTheFirstPressWarnsAndTheSecondRestarts() async throws {
        await app.set(update: "0.3.0", calls: 2)
        let spot = try spot("updates")
        let effects = try recordEffects()

        try await spot.perform("update", timeout: 60)
        let warned = try await spot.state(timeout: 60)
        let first = await app.installs
        _ = try await spot.perform("update", timeout: 60)
        let second = await app.installs

        XCTAssertEqual(effects(), ["toast Restarting stops 2 calls. Press again to restart."])
        XCTAssertEqual(warned, SpotState(title: "Restart", subtitle: "Stops 2 calls"))
        XCTAssertEqual(first, 0)
        XCTAssertEqual(second, 1)
    }

    func testOneRunningCallIsNamedInTheSingular() async throws {
        await app.set(update: "0.3.0", calls: 1)
        let effects = try recordEffects()

        try await spot("updates").perform("update", timeout: 60)

        XCTAssertEqual(effects(), ["toast Restarting stops 1 call. Press again to restart."])
    }

    func testWhenTheWorkChangesAPressWarnsAgain() async throws {
        let spot = try spot("updates")
        await app.set(update: "0.3.0", calls: 2)
        _ = try await spot.perform("update", timeout: 60)
        await app.set(update: "0.3.0", calls: 1)

        _ = try await spot.perform("update", timeout: 60)

        let installs = await app.installs
        XCTAssertEqual(installs, 0)
    }

    func testAWarningEndsWithItsUpdate() async throws {
        let spot = try spot("updates")
        await app.set(update: "0.3.0", calls: 2)
        _ = try await spot.perform("update", timeout: 60)
        await app.set(update: nil, calls: 2)
        _ = try await spot.state(timeout: 60)
        await app.set(update: "0.4.0", calls: 2)
        let effects = try recordEffects()

        try await spot.perform("update", timeout: 60)

        XCTAssertEqual(effects(), ["toast Restarting stops 2 calls. Press again to restart."])
        let installs = await app.installs
        XCTAssertEqual(installs, 0)
    }
}
