import XCTest
@testable import OpenspotCore

final class EmojiCatalogTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-emoji-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(names: [String: String], language: String = "en", order: [String]) throws {
        let place = folder.appendingPathComponent("\(language).lproj")
        try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: names, format: .binary, options: 0)
        try data.write(to: place.appendingPathComponent("AppleName.strings"))
        try writeOrder(order)
    }

    private func writeOrder(_ order: [String]) throws {
        var meta = Data([0, 0, 1])
        for emoji in order { meta += Data(emoji.utf8) + Data([0, 2]) }
        try meta.write(to: folder.appendingPathComponent("emojimeta.dat"))
    }

    private func rows(tone: EmojiCatalog.Tone = .none, languages: [String] = ["en"]) throws -> [SpotItem] {
        PluginOutput(text: try EmojiCatalog(resources: folder, languages: languages).rows(tone: tone)).items
    }

    func testRowsFollowTheOrderOfTheMac() throws {
        try write(names: ["😂": "joy", "😀": "grin"], order: ["😀", "😂"])

        XCTAssertEqual(try rows().map(\.title), ["grin", "joy"])
    }

    func testAnEmojiWithNoPlaceInTheOrderComesLast() throws {
        try write(names: ["🥰": "love", "😀": "grin"], order: ["😀"])

        XCTAssertEqual(try rows().map(\.title), ["grin", "love"])
    }

    func testARowRunsAndDrawsItsEmoji() throws {
        try write(names: ["😀": "grin"], order: ["😀"])
        let row = try XCTUnwrap(try rows().first)

        XCTAssertEqual(row.run, "😀")
        XCTAssertEqual(row.glyph, "😀")
    }

    func testAToneTakesTheFormThatTheMacHas() throws {
        try write(names: ["👍": "thumbs up", "😀": "grin"], order: ["😀", "👍", "👍🏽"])

        XCTAssertEqual(try rows(tone: .medium).map(\.run), ["😀", "👍🏽"])
    }

    func testAToneReachesBothPeopleOfAPairAndNotTheirHands() throws {
        try write(names: ["🧑‍🤝‍🧑": "people"], order: ["🧑‍🤝‍🧑", "🧑🏽‍🤝‍🧑🏽"])

        XCTAssertEqual(try rows(tone: .medium).map(\.run), ["🧑🏽‍🤝‍🧑🏽"])
    }

    func testAToneDropsTheMarkThatAskedForAPicture() throws {
        try write(names: ["⛹️‍♂️": "man with ball"], order: ["⛹️‍♂️", "⛹🏽‍♂️"])

        XCTAssertEqual(try rows(tone: .medium).map(\.run), ["⛹🏽‍♂️"])
    }

    func testAnEmojiWithNoFormInThatToneStaysYellow() throws {
        try write(names: ["👨‍👩‍👧": "family"], order: ["👨‍👩‍👧"])

        XCTAssertEqual(try rows(tone: .medium).map(\.run), ["👨‍👩‍👧"])
    }

    func testAVariantForARegionIsLeftOut() throws {
        try write(names: ["😀": "grin", "🇹🇼@CH-SKU": "flag"], order: ["😀"])

        XCTAssertEqual(try rows().map(\.title), ["grin"])
    }

    func testNamesComeInTheFirstLanguageTheMacHas() throws {
        try write(names: ["👍": "thumbs up"], order: ["👍"])
        try write(names: ["👍": "большой палец"], language: "ru", order: ["👍"])

        XCTAssertEqual(try rows(languages: ["ru-RU", "en-US"]).map(\.title), ["большой палец"])
        XCTAssertEqual(try rows(languages: ["xx-XX"]).map(\.title), ["thumbs up"])
    }

    func testARegionOfALanguageWinsOverTheLanguage() throws {
        try write(names: ["👍": "thumbs up"], order: ["👍"])
        try write(names: ["👍": "thumbs up, mate"], language: "en_AU", order: ["👍"])

        XCTAssertEqual(try rows(languages: ["en-AU"]).map(\.title), ["thumbs up, mate"])
    }

    func testMissingFilesSayTheCause() {
        XCTAssertThrowsError(try EmojiCatalog(resources: folder, languages: ["en"]).rows(tone: .none)) { error in
            XCTAssertEqual((error as? PluginError)?.reason, "This Mac has no emoji names. Update macOS, or tell the plugin's author.")
        }
    }

    func testTheEmojiOfThisMac() throws {
        guard FileManager.default.fileExists(atPath: EmojiCatalog.standardResources.path) else { throw XCTSkip("No emoji files.") }
        let catalog = EmojiCatalog(languages: ["en"])
        let plain = PluginOutput(text: try catalog.rows(tone: .none)).items
        let toned = PluginOutput(text: try catalog.rows(tone: .medium)).items

        XCTAssertGreaterThan(plain.count, 1000)
        XCTAssertEqual(toned.count, plain.count)
        XCTAssertTrue(toned.contains { $0.run == "👍🏽" && $0.title == "thumbs up" })
        XCTAssertTrue(toned.contains { $0.run == "🧑🏽‍🤝‍🧑🏽" })
        XCTAssertTrue(toned.contains { $0.run == "👨‍👩‍👧" })
        XCTAssertEqual(plain.first?.run, "😀")
    }
}
