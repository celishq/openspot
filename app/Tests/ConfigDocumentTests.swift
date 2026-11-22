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

        XCTAssertEqual(document.tables(named: "widgets").first?["places"], .table(["a": .string("one"), "b": .string("two")]))
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

    func testReadsATableOfTextsBooleansNumbersAndListsAndWritesItBack() throws {
        let text = "[actions.snooze]\ninputs.url = { default = 2, options = [\"a\", 'b'], required = true, type = \"url\", weight = 0.5 }\n"

        let document = try ConfigDocument(text: text)

        XCTAssertEqual(document.sections.first?["inputs.url"], .table([
            "type": .string("url"), "required": .boolean(true), "default": .integer(2), "options": .strings(["a", "b"]), "weight": .number(0.5)
        ]))
        XCTAssertEqual(document.text, text.replacingOccurrences(of: "'b'", with: "\"b\""))
    }
}
