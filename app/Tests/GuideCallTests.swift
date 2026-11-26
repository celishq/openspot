import XCTest
@testable import OpenspotCore

final class GuideCallTests: XCTestCase {
    private var api: CommandAPI!

    override func setUpWithError() throws {
        let folder = try temporaryFolder()
        let guide = """
        # How Openspot works

        Start with [Your first spot](#your-first-spot).

        ## Show

        - [A list](#a-list)

        ## Reference

        - [spot.toml](#spottoml)

        # Your first spot

        Make a folder. Its keys are in [Keys](#spottoml/keys).

        # A list

        Print rows.

        ```sh
        ## not a section
        ```

        ## Rows

        One per item.

        ### A row

        Its keys.

        # spot.toml

        The file.

        ## Keys

        | Key     | Type | Is                        |
        | ------- | ---- | ------------------------- |
        | `title` | text | The name.                 |
        | `stay`  | bool | Whether it keeps running. |

        ## [on]

        | Key      | Is                          |
        | -------- | --------------------------- |
        | `search` | A pattern that a search matches. |
        | `stay`   | Not a key of on.            |

        """
        try guide.write(to: folder.appendingPathComponent("DOCS.md"), atomically: true, encoding: .utf8)
        api = CommandAPI(mac: Mac(guide: folder.appendingPathComponent("DOCS.md")), places: .test(["OPENSPOT_CONFIG": folder.path]))
    }

    private func answer(_ arguments: String...) async throws -> CommandAnswer {
        try await XCTUnwrap(api.work(for: .test(["guide"] + arguments), input: { "" }))()
    }

    func testAnAddressOfAPageAndASectionPrintsThatSectionWithItsSubsections() async throws {
        let rows = try await answer("a-list/rows")
        let on = try await answer("spottoml/on")

        XCTAssertEqual(rows.output, "## Rows\n\nOne per item.\n\n### A row\n\nIts keys.\n")
        XCTAssertTrue(on.output.hasPrefix("## [on]\n\n| Key"), on.output)
        XCTAssertFalse(on.output.contains("## Keys"), on.output)
    }

    func testALinkPrintsAsTheCommandThatOpensIt() async throws {
        let first = try await answer("your-first-spot")

        XCTAssertEqual(first.output, "# Your first spot\n\nMake a folder. Its keys are in Keys (`openspot guide spottoml/keys`).\n")
    }

    func testAWordPrintsEachReferenceRowThatNamesItUnderItsHeader() async throws {
        let stay = try await answer("stay")
        let on = try await answer("[on]")

        XCTAssertEqual(stay.output, """
        | Key     | Type | Is                        |
        | ------- | ---- | ------------------------- |
        | `stay`  | bool | Whether it keeps running. |
        From `openspot guide spottoml/keys`.

        | Key      | Is                          |
        | -------- | --------------------------- |
        | `stay`   | Not a key of on.            |
        From `openspot guide spottoml/on`.

        """)
        XCTAssertTrue(on.output.hasPrefix("## [on]\n"), on.output)
    }

    func testFindPrintsEachPartThatHoldsEveryWordWithItsFirstLineThatDoes() async throws {
        let found = try await answer("--find", "keeps", "running")
        let none = try await answer("--find", "weather")

        XCTAssertEqual(found.output, "spottoml/keys    | `stay`  | bool | Whether it keeps running. |\n")
        XCTAssertEqual(none.code, 1)
        XCTAssertEqual(none.errors, "No part of the guide holds weather. Run `openspot guide` for the map.\n")
    }

    func testAHeadingInAFenceIsNoSection() async throws {
        let missing = try await answer("a-list/not-a-section")

        XCTAssertEqual(missing.code, 2)
        XCTAssertEqual(missing.errors, "The page a-list has no section not-a-section. Its sections are `openspot guide a-list/rows`.\n")
    }
}
