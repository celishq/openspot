import XCTest
@testable import OpenspotCore

final class SymbolCatalogTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-symbols-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func write(category: String, data: String) throws {
        try write(category: category, list: ["Data": data])
    }

    private func write(category: String, sections: [(String, String)]) throws {
        try write(category: category, list: ["DataArray": sections.map { ["CVDataTitle": $0.0, "Data": $0.1] }])
    }

    private func write(category: String, list: [String: Any]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: ["CVCategoryData": list], format: .binary, options: 0)
        try data.write(to: folder.appendingPathComponent("Category-\(category).plist"))
    }

    private func write(titles: [String: [String: String]]) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: titles, format: .binary, options: 0)
        try data.write(to: folder.appendingPathComponent("Localizable.loctable"))
    }

    private func rows(languages: [String] = ["en"]) throws -> [SpotItem] {
        PluginOutput(text: try SymbolCatalog(resources: folder, languages: languages).rows()).items
    }

    func testRowsFollowTheOrderOfTheCharacterViewer() throws {
        try write(category: "Bullets", data: "•")
        try write(category: "Arrows", data: "→,←")

        XCTAssertEqual(try rows().map(\.run), ["→", "←", "•"])
    }

    func testARowIsNamedForItsSymbolAndDrawsIt() throws {
        try write(category: "Arrows", data: "→")
        let row = try XCTUnwrap(try rows().first)

        XCTAssertEqual(row.title, "rightwards arrow")
        XCTAssertEqual(row.run, "→")
        XCTAssertEqual(row.glyph, "→")
    }

    func testACodeStandsForItsSymbol() throws {
        try write(category: "Punctuation", data: "0x2C,0x1F8A1")

        XCTAssertEqual(try rows().map(\.run), [",", "\u{1F8A1}"])
    }

    func testTheSubtitleIsTheSectionOrElseTheCategory() throws {
        try write(category: "Arrows", sections: [("SectionTitle-RightArrows", "→")])
        try write(category: "Bullets", data: "•")
        try write(titles: ["en": ["SectionTitle-RightArrows": "Rightwards Arrows", "CategoryName-Bullets": "Bullets & Stars"]])

        XCTAssertEqual(try rows().map(\.subtitle), ["Rightwards Arrows", "Bullets & Stars"])
    }

    func testTitlesComeInTheFirstLanguageTheMacHas() throws {
        try write(category: "Bullets", data: "•")
        try write(titles: ["en": ["CategoryName-Bullets": "Bullets & Stars"], "ru": ["CategoryName-Bullets": "Значки и звезды"]])

        XCTAssertEqual(try rows(languages: ["ru-RU", "en-US"]).map(\.subtitle), ["Значки и звезды"])
        XCTAssertEqual(try rows(languages: ["xx-XX"]).map(\.subtitle), ["Bullets & Stars"])
    }

    func testASymbolInTwoCategoriesShowsOnceInTheFirst() throws {
        try write(category: "Arrows", data: "☞")
        try write(category: "Bullets", data: "☞,•")

        XCTAssertEqual(try rows().map(\.run), ["☞", "•"])
    }

    func testASymbolWithNoNameIsLeftOut() throws {
        try write(category: "Arrows", data: "0x378,→")

        XCTAssertEqual(try rows().map(\.run), ["→"])
    }

    func testATextFormIsNamedForItsSymbol() throws {
        try write(category: "Arrows", data: "➡︎")

        XCTAssertEqual(try rows().map(\.title), ["black rightwards arrow"])
    }

    func testMissingFilesSayTheCause() {
        XCTAssertThrowsError(try SymbolCatalog(resources: folder, languages: ["en"]).rows()) { error in
            XCTAssertEqual((error as? PluginError)?.reason, "This Mac has no symbol lists. Update macOS, or tell the plugin's author.")
        }
    }

    func testTheSymbolsOfThisMac() throws {
        guard FileManager.default.fileExists(atPath: SymbolCatalog.standardResources.path) else { throw XCTSkip("No symbol files.") }
        let rows = PluginOutput(text: try SymbolCatalog(languages: ["en"]).rows()).items

        XCTAssertGreaterThan(rows.count, 500)
        XCTAssertEqual(rows.first?.run, "→")
        XCTAssertEqual(rows.first?.subtitle, "Rightwards Arrows")
        XCTAssertTrue(rows.contains { $0.run == "€" && $0.title == "euro sign" && $0.subtitle == "Currency Symbols" })
        XCTAssertTrue(rows.contains { $0.run == "⌘" })
    }
}
