import XCTest
@testable import OpenspotCore

final class ConfigDocumentTests: XCTestCase {
    func testReadsValuesAndArraysOfTables() throws {
        let document = try ConfigDocument(text: """
        # A comment
        name = "Folders" # after a value
        api = 1
        on = true

        [[commands]]
        name = "Downloads"

        [[commands]]
        name = "Say \\"hi\\" # now"
        """)

        XCTAssertEqual(document.values["name"], .string("Folders"))
        XCTAssertEqual(document.values["api"], .integer(1))
        XCTAssertEqual(document.values["on"], .boolean(true))
        XCTAssertEqual(document.tables(named: "commands").map { $0["name"] }, [.string("Downloads"), .string("Say \"hi\" # now")])
    }

    func testReadsATableOfStrings() throws {
        let document = try ConfigDocument(text: "[[widgets]]\nplaces = { a = \"one\", b = \"two\" } # both\n")

        XCTAssertEqual(document.tables(named: "widgets").first?["places"], .table(["a": "one", "b": "two"]))
    }

    func testRefusesATableWithARepeatedKey() {
        XCTAssertThrowsError(try ConfigDocument(text: "places = { a = \"one\", a = \"two\" }\n"))
    }

    func testNamesTheLineOfAFault() {
        XCTAssertThrowsError(try ConfigDocument(text: "name = \"A\"\nnot a pair\n")) { error in
            XCTAssertEqual(error as? SpotError, .fault("line 2: expected a key and a value"))
        }
    }

    func testRefusesARepeatedKey() {
        XCTAssertThrowsError(try ConfigDocument(text: "a = 1\na = 2\n")) { error in
            XCTAssertEqual(error as? SpotError, .fault("line 2: a is set twice"))
        }
    }

    func testRefusesAnUnclosedString() {
        XCTAssertThrowsError(try ConfigDocument(text: "a = \"open\n"))
    }

    func testReadsSectionsAndNumbersAndWritesThemBack() throws {
        let text = "name = \"A\"\n\n[dark]\nink = \"#FFFFFF\"\nfill = 0.1\n\n[light]\nfill = 0\n\n[[commands]]\nname = \"B\"\n"

        let document = try ConfigDocument(text: text)

        XCTAssertEqual(document.values["name"], .string("A"))
        XCTAssertEqual(document.sections.map(\.name), ["dark", "light"])
        XCTAssertEqual(document.sections.first?["ink"], .string("#FFFFFF"))
        XCTAssertEqual(document.sections.first?["fill"], .number(0.1))
        XCTAssertEqual(document.sections.last?["fill"], .integer(0))
        XCTAssertEqual(document.tables(named: "commands").first?["name"], .string("B"))
        XCTAssertEqual(document.text, text)
    }

    func testRefusesASectionSetTwice() {
        XCTAssertThrowsError(try ConfigDocument(text: "[dark]\n[light]\n[dark]\n")) { error in
            XCTAssertEqual(error as? SpotError, .fault("line 3: [dark] is set twice"))
        }
    }

    func testASettingReplacesTheKeyOfItsSectionAndKeepsEachOtherLine() {
        let text = "# My theme\n[dark]\nink = \"#FFFFFF\"\n# a note\nfill = 0.1\n\n[light]\nfill = 0.2\n"

        let changed = ConfigDocument.text(text, setting: "fill", in: "light", to: .number(0.3))

        XCTAssertEqual(changed, "# My theme\n[dark]\nink = \"#FFFFFF\"\n# a note\nfill = 0.1\n\n[light]\nfill = 0.3\n")
    }

    func testASettingUncommentsTheLineThatNewWrote() {
        let text = "[space]\n# cell = 64\n# padding = 13\n\n[radius]\n# card = 26\n"

        let changed = ConfigDocument.text(text, setting: "padding", in: "space", to: .integer(20))

        XCTAssertEqual(changed, "[space]\n# cell = 64\npadding = 20\n\n[radius]\n# card = 26\n")
    }

    func testASettingAddsAKeyAndASectionThatTheFileLacks() {
        let added = ConfigDocument.text("[space]\ncell = 60\n\n[radius]\ncard = 20\n", setting: "padding", in: "space", to: .integer(9))
        let made = ConfigDocument.text("[space]\ncell = 60\n", setting: "accent", in: "shared", to: .string("#FF9F0A"))
        let first = ConfigDocument.text("", setting: "card", in: "radius", to: .integer(20))

        XCTAssertEqual(added, "[space]\ncell = 60\npadding = 9\n\n[radius]\ncard = 20\n")
        XCTAssertEqual(made, "[space]\ncell = 60\n\n[shared]\naccent = \"#FF9F0A\"\n")
        XCTAssertEqual(first, "[radius]\ncard = 20\n")
    }

    func testAResetCommentsTheKeyOut() throws {
        let text = "[space]\ncell = 60\npadding = 9\n"

        let reset = ConfigDocument.text(text, setting: "padding", in: "space", to: nil)

        XCTAssertEqual(reset, "[space]\ncell = 60\n# padding = 9\n")
        XCTAssertNil(try ConfigDocument(text: reset).sections.first?["padding"])
        XCTAssertEqual(ConfigDocument.text(reset, setting: "padding", in: "space", to: nil), reset)
    }

    func testASettingFindsASectionWrittenWithSpacesOrACommentAndKeepsTheCommentOfItsLine() {
        let text = "[ dark ]  # night\nfill = 0.1  # soft\n"

        let changed = ConfigDocument.text(text, setting: "fill", in: "dark", to: .number(0.3))
        let added = ConfigDocument.text(text, setting: "ink", in: "dark", to: .string("#000000"))

        XCTAssertEqual(changed, "[ dark ]  # night\nfill = 0.3  # soft\n")
        XCTAssertEqual(added, "[ dark ]  # night\nfill = 0.1  # soft\nink = \"#000000\"\n")
    }

    func testASettingUncommentsOnlyALineThatHoldsAValue() {
        let text = "[radius]\n# card = the corner of each card\n"

        let changed = ConfigDocument.text(text, setting: "card", in: "radius", to: .integer(20))

        XCTAssertEqual(changed, "[radius]\n# card = the corner of each card\ncard = 20\n")
    }
}
