import XCTest
@testable import OpenspotCore

final class SpotPromptTests: XCTestCase {
    private var folder: URL!
    private var examples: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-prompt-\(UUID().uuidString)")
        examples = folder.appendingPathComponent("examples")
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func prompt(app: String = "openspot") -> SpotPrompt {
        SpotPrompt(folder: folder, references: [examples], app: app)
    }

    private var weather: URL {
        folder.appendingPathComponent("weather.spot/weather.sh")
    }

    func testThePromptNamesTheClientBesideTheApp() throws {
        let app = folder.appendingPathComponent("Contents/MacOS/Openspot").path
        let client = folder.appendingPathComponent("Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/bin/sh\n".writeScript(to: client)

        XCTAssertEqual(SpotPrompt.command(of: app), client.path)
    }

    func testThePromptNamesTheAppWhenNoClientIsBesideIt() {
        let app = folder.appendingPathComponent("Contents/MacOS/Openspot").path

        XCTAssertEqual(SpotPrompt.command(of: app), app)
    }

    func testEachCommandGivesAPathWithASpaceInQuotes() {
        let app = "/Apps/Openspot Nightly.app/Contents/Helpers/openspot"
        let text = prompt(app: app).building("Show the weather")

        XCTAssertTrue(text.contains("\"\(app)\" guide build-and-check-a-spot"))
        XCTAssertTrue(text.contains("\"\(app)\" check spots --json"))
        XCTAssertTrue(text.contains("\"\(app)\" spot open"))
        XCTAssertFalse(text.contains(" \(app) "))
    }

    func testEachPromptGivesItsPartsInOneOrderWithTheRequestLast() {
        let texts = [
            prompt().building("Show the weather"),
            prompt().changing(weather, wish: "Show the weather"),
            prompt().fixing(weather, faults: ["Weather has an unknown key."])
        ]

        for text in texts {
            let parts = ["Where:", "Read first:", "Rules:", "<request>"].map { text.range(of: $0)?.lowerBound }
            XCTAssertFalse(parts.contains(nil), text)
            XCTAssertEqual(parts.compactMap { $0 }, parts.compactMap { $0 }.sorted(), text)
            XCTAssertTrue(text.hasSuffix("</request>"), text)
        }
        XCTAssertTrue(texts[0].hasSuffix("<request>\nShow the weather\n</request>"))
    }

    func testThePromptReadsTheGuideByTopicAndPointsAtWorkingSpots() {
        let text = prompt().building("Show the weather")

        XCTAssertTrue(text.contains("guide for the map of the guide"))
        XCTAssertTrue(text.contains("guide <word> for the row of a key, a block, a class or a command"))
        XCTAssertFalse(text.contains("read all of it"))
        XCTAssertTrue(text.contains(examples.path))
        XCTAssertTrue(text.contains(folder.path))
    }

    func testNoPromptAsksThePersonAnything() {
        let texts = [
            prompt().building("Show the weather"),
            prompt().changing(weather),
            prompt().fixing(weather, faults: ["Weather has an unknown key."])
        ]

        for text in texts {
            XCTAssertTrue(text.contains(AgentPrompt.noQuestion), text)
            XCTAssertFalse(text.contains("Ask me"), text)
        }
    }

    func testEachSpotPromptAsksForTheSimplestWayAndAWhyForAnyOther() {
        let texts = [
            prompt().building("Show the weather"),
            prompt().changing(weather, wish: "Show the weather"),
            prompt().fixing(weather, faults: ["Weather has an unknown key."])
        ]

        for text in texts {
            XCTAssertTrue(text.contains(SpotPrompt.simplest), text)
        }
    }

    func testAChangeNamesTheSpotItsLogAndItsLastFailure() {
        let text = prompt().changing(weather, wish: "Add a refresh button", failure: "The server did not answer.")

        XCTAssertTrue(text.contains(weather.path))
        XCTAssertTrue(text.contains("spot log weather"))
        XCTAssertTrue(text.contains("The server did not answer."))
        XCTAssertTrue(text.hasSuffix("<request>\nAdd a refresh button\n</request>"))
    }

    func testAChangeWithNoWishAndNoCountsAsksForAReview() {
        XCTAssertTrue(prompt().changing(weather).hasSuffix("<request>\n\(SpotPrompt.review)\n</request>"))
    }

    func testAFixGivesTheFaultsAndAsksToLoadTheSpotAgain() {
        let text = prompt().fixing(weather, faults: ["Weather has an unknown key."])

        XCTAssertTrue(text.contains("Weather has an unknown key."))
        XCTAssertTrue(text.hasSuffix("<request>\n\(SpotPrompt.loadAgain)\n</request>"))
    }
}
