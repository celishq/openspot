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

    func testRefusesAPlainTable() {
        XCTAssertThrowsError(try ConfigDocument(text: "[table]\n"))
    }
}
