import XCTest
@testable import OpenspotCore

final class TomlDocumentTests: XCTestCase {
    func testReadsValuesAndArraysOfTables() throws {
        let document = try TomlDocument(text: """
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
        XCTAssertEqual(document.arrays["commands"]?.map { $0["name"] }, [.string("Downloads"), .string("Say \"hi\" # now")])
    }

    func testReadsATableOfStrings() throws {
        let document = try TomlDocument(text: "[[widgets]]\nplaces = { a = \"one\", b = \"two\" } # both\n")

        XCTAssertEqual(document.arrays["widgets"]?.first?["places"], .table(["a": "one", "b": "two"]))
    }

    func testRefusesATableWithARepeatedKey() {
        XCTAssertThrowsError(try TomlDocument(text: "places = { a = \"one\", a = \"two\" }\n"))
    }

    func testNamesTheLineOfAFault() {
        XCTAssertThrowsError(try TomlDocument(text: "name = \"A\"\nnot a pair\n")) { error in
            XCTAssertEqual(error as? PluginError, .fault("line 2: expected a key and a value"))
        }
    }

    func testRefusesARepeatedKey() {
        XCTAssertThrowsError(try TomlDocument(text: "a = 1\na = 2\n")) { error in
            XCTAssertEqual(error as? PluginError, .fault("line 2: a is set twice"))
        }
    }

    func testRefusesAnUnclosedString() {
        XCTAssertThrowsError(try TomlDocument(text: "a = \"open\n"))
    }

    func testRefusesAPlainTable() {
        XCTAssertThrowsError(try TomlDocument(text: "[table]\n"))
    }
}
