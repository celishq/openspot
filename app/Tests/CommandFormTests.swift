import XCTest
@testable import OpenspotCore

final class CommandFormTests: XCTestCase {
    func testTheFormNamesEachOptionAndWhetherItTakesAValue() {
        let words = CommandForm("[--days n] [--spot id] [--json]").fit(["--json", "--days", "7"])

        XCTAssertEqual(words?.value("--days"), "7")
        XCTAssertNil(words?.value("--spot"))
        XCTAssertEqual(words?.has("--json"), true)
        XCTAssertEqual(words?.rest, [])
    }

    func testWordsThatAreNoOptionStayInOrder() {
        let words = CommandForm("<id> [page] [--replace] [--title <words>]").fit(["notes", "--title", "My notes", "edit"])

        XCTAssertEqual(words?.rest, ["notes", "edit"])
        XCTAssertEqual(words?.value("--title"), "My notes")
        XCTAssertEqual(words?.has("--replace"), false)
    }

    func testARepeatedOptionGivesEachValue() {
        let words = CommandForm("[--days n] [--hide id]...").fit(["--hide", "a", "--hide", "b"])

        XCTAssertEqual(words?.values("--hide"), ["a", "b"])
    }

    func testTheFormRefusesAnUnknownOptionATwiceGivenOneAndAMissingValue() {
        let form = CommandForm("[--days n] [--json]")

        XCTAssertNil(form.fit(["--all"]))
        XCTAssertNil(form.fit(["--json", "--json"]))
        XCTAssertNil(form.fit(["--days"]))
    }

    func testAnOpenFormPassesOtherWordsThatLookLikeOptions() {
        XCTAssertEqual(CommandForm("<id> [call] [value]...").fit(["notes", "--x"])?.rest, ["notes", "--x"])
        XCTAssertEqual(CommandForm("[--dry-run] <words>...").fit(["--dry-run", "buy", "--fast"])?.rest, ["buy", "--fast"])
    }

    func testAnOptionCanBeOneChoiceOfAGroup() {
        let form = CommandForm("[topic | --topics]")

        XCTAssertEqual(form.fit(["--topics"])?.has("--topics"), true)
        XCTAssertEqual(form.fit(["rows"])?.rest, ["rows"])
    }
}
