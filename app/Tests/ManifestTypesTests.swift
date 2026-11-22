import XCTest
@testable import OpenspotCore

final class ManifestTypesTests: XCTestCase {
    private static let toml = """
    title = "Snooze Tab"
    stay = true

    [settings]
    browser = { type = "choice", options = ["Safari", "Chrome"], default = "Safari", title = "Browser", description = "Where tabs open" }
    token = "secret"
    limit = "number"

    [actions.snooze]
    title = "Snooze Tab"
    icon = "moon"
    confirm = "Snooze again"
    inputs.url = { type = "url", required = true, description = "The tab to snooze" }
    inputs.text = "text"
    inputs.count = "number"
    inputs.loud = "bool"
    inputs.at = "date"
    inputs.wait = "duration"
    inputs.file = "file"
    inputs.key = "secret"
    inputs.tags = "[text]"
    inputs.size = { type = "choice", options = ["s", "m"], default = "m" }
    outputs.until = "date"

    [actions.wake]
    inputs.url = "url"

    [actions.go]
    title = "Go"
    """

    private func spot(_ toml: String) throws -> (spot: Spot?, refused: [String]) {
        let spots = try temporaryFolder()
        try "#!/bin/sh\necho\n".writeScript(to: spots.appendingPathComponent("snooze.spot/snooze.sh"), toml: toml)
        let scan = try SpotsFolder(url: spots).scan()
        return (scan.spots.first, scan.refused.map(\.reason))
    }

    func testActionsAndSettingsReadEachType() throws {
        let manifest = try Manifest(text: Self.toml, folder: "/spots/snooze.spot").script("snooze.sh")

        let snooze = try XCTUnwrap(manifest.actions.first)
        XCTAssertEqual(manifest.actions.map(\.id), ["snooze", "wake", "go"])
        XCTAssertEqual(snooze.title, "Snooze Tab")
        XCTAssertEqual(snooze.icon, "moon")
        XCTAssertEqual(snooze.confirm, "Snooze again")
        XCTAssertEqual(snooze.inputs.map(\.name), ["url", "text", "count", "loud", "at", "wait", "file", "key", "tags", "size"])
        XCTAssertEqual(snooze.inputs.map(\.type.name), ["url", "text", "number", "bool", "date", "duration", "file", "secret", "[text]", "choice"])
        XCTAssertEqual(snooze.inputs.first?.isRequired, true)
        XCTAssertEqual(snooze.inputs.first?.detail, "The tab to snooze")
        XCTAssertEqual(snooze.inputs.last?.options, ["s", "m"])
        XCTAssertEqual(snooze.inputs.last?.defaultValue, "m")
        XCTAssertEqual(snooze.outputs.map(\.name), ["until"])
        XCTAssertEqual(manifest.stay, true)
        XCTAssertEqual(manifest.settings.map(\.id), ["browser", "token", "limit"])
        XCTAssertEqual(manifest.settings.first?.title, "Browser")
        XCTAssertEqual(manifest.settings.first?.options, ["Safari", "Chrome"])
        XCTAssertEqual(manifest.settings.first?.defaultValue, "Safari")
        XCTAssertEqual(manifest.settings.map(\.isSecret), [false, true, false])
    }

    func testATypedSettingTakesAnIcon() throws {
        let manifest = try Manifest(text: "[settings]\nmorning = { type = \"choice\", icon = \"sunrise\", options = [\"8:00\"] }", folder: "/spots/snooze.spot").script("snooze.sh")

        XCTAssertEqual(manifest.settings.first?.icon, "sunrise")
    }

    func testASpotStaysAndOffersEachTitledActionWithItsCommands() throws {
        let spot = try XCTUnwrap(spot(Self.toml).spot)

        XCTAssertEqual(spot.mode, .stay)
        XCTAssertEqual(spot.typedActions.map(\.id), ["snooze", "wake", "go"])
        XCTAssertEqual(spot.offers.map(\.id), ["snooze", "go"])
        XCTAssertEqual(spot.offers.first?.title, "Snooze Tab")
    }

    func testAWrongTypeFailsTheLoadWithALineThatNamesTheKey() throws {
        let cases = [
            "[actions.wake]\ninputs.url = \"link\"": "inputs.url",
            "[actions.wake]\noutputs.at = { type = \"when\" }": "outputs.at",
            "[settings]\ncity = \"place\"": "city",
            "[settings]\ncity = 3": "city",
            "[actions.wake]\ninputs.url = { type = \"url\", required = \"yes\" }": "required",
            "[actions.wake]\ninputs.size = { type = \"choice\" }": "options",
            "[actions.wake]\ninputs.count = { type = \"number\", default = \"many\" }": "default",
            "stay = \"yes\"": "stay"
        ]
        for (toml, key) in cases {
            let refused = try spot(toml).refused

            XCTAssertEqual(refused.count, 1, toml)
            XCTAssertTrue(refused.first?.contains(key) == true, "\(toml): \(refused)")
        }
    }

    func testAnUnknownKeyFailsTheLoadWithALineThatNamesIt() throws {
        let cases = [
            "[actions.wake]\ntitel = \"Wake\"": "titel",
            "[actions.wake]\ninputs.url = { type = \"url\", requird = true }": "requird",
            "[settings]\ncity = { type = \"text\", required = true }": "required",
            "[actions.wake]\nresults.url = \"url\"": "results.url"
        ]
        for (toml, key) in cases {
            let refused = try spot(toml).refused

            XCTAssertEqual(refused.count, 1, toml)
            XCTAssertTrue(refused.first?.contains(key) == true, "\(toml): \(refused)")
        }
    }

    func testEachKeyOfTheOldFormFailsAsAnUnknownKey() throws {
        let cases = [
            "mode = \"stay\"": "mode", "on = [\"panel.open\"]": "on", "offers = [\"search\"]": "offers", "placeholder = \"Text\"": "placeholder",
            "drop = \"png\"": "drop", "emits = [\"music.track\"]": "emits", "[commands.go]\ntitle = \"Go\"": "commands",
            "[settings.city]\ntitle = \"City\"": "settings", "[scripts.other]\ntitle = \"Other\"": "scripts"
        ]
        for (toml, key) in cases {
            let refused = try spot(toml).refused

            XCTAssertEqual(refused, ["Snooze has an unknown key in its spot.toml: \(key)"], toml)
        }
    }

    func testStayFalseRunsAProcessPerCall() throws {
        XCTAssertEqual(try spot("stay = false").spot?.mode, .once)
    }
}
