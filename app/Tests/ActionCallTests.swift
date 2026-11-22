import XCTest
@testable import OpenspotCore

@MainActor
final class ActionCallTests: SpotRunsCase {
    private let marker = "MARKER-a91d"

    private static let toml = """
    [settings]
    token = "secret"
    city = { type = "text", default = "Paris" }

    [actions.make]
    outputs.code = { type = "number", required = true }

    [actions.take]
    inputs.code = { type = "number", required = true }
    inputs.size = { type = "choice", options = ["s", "m"], default = "m" }

    [actions.wrong]
    outputs.code = "number"

    [actions.broken]
    """

    private func text(_ name: String) -> String {
        (try? String(contentsOfFile: path(name), encoding: .utf8)) ?? ""
    }

    private func spot(_ body: String = "") throws -> SpotRun {
        try script(toml: Self.toml, """
        . "$OPENSPOT_SH"
        openspot_input > '\(path("stdin"))'
        case "$1" in
          make) echo "out.code=42" ;;
          take) printf '%s %s' "$(value code)" "$(value size)" > '\(path("took"))' ;;
          wrong) echo "out.code=many" ;;
          broken) printf 'error=The disk is full\\n' ;;
          \(body)
        esac
        """)
        return try sheet()
    }

    func testAnActionTakesAnInputReadFromTheRealOutputOfAnother() async throws {
        let sheet = try spot()

        let made = try await sheet.call("make")
        _ = try await sheet.call("take", inputs: made)

        XCTAssertEqual(made, [TextBlock.Field(key: "code", value: "42")])
        XCTAssertEqual(text("took"), "42 m")
        XCTAssertTrue(text("stdin").contains("input.code=42\ninput.size=m\n"), text("stdin"))
    }

    func testAnInputOfTheWrongTypeOrAMissingRequiredOneFailsBeforeTheCall() async throws {
        let sheet = try spot()

        for inputs in [[TextBlock.Field(key: "code", value: "many")], [], [.init(key: "code", value: "1"), .init(key: "size", value: "xl")]] {
            do {
                _ = try await sheet.call("take", inputs: inputs)
                XCTFail("\(inputs) should fail")
            } catch {
                XCTAssertTrue(SpotsModel.reason(error).contains(inputs.last?.key ?? "code"), SpotsModel.reason(error))
            }
        }
        XCTAssertFalse(log().contains { $0.hasPrefix("take") })
    }

    func testAnOutputOfTheWrongTypeAndAnErrorInTheRootFailTheCall() async throws {
        let sheet = try spot()

        for (action, reason) in [("wrong", "code"), ("broken", "The disk is full")] {
            do {
                _ = try await sheet.call(action)
                XCTFail("\(action) should fail")
            } catch {
                XCTAssertTrue(SpotsModel.reason(error).contains(reason), SpotsModel.reason(error))
            }
        }
    }

    func testEachCallGetsThePlainSettingsAndNeverASecret() async throws {
        let store = SecretStore(file: folder.appendingPathComponent("secrets.json"))
        try store.keep(marker, key: "token", of: "script")
        runs.secrets = store
        let sheet = try spot()

        _ = try await sheet.call("make")

        XCTAssertTrue(text("stdin").contains("setting.city=Paris\n"), text("stdin"))
        XCTAssertFalse(text("stdin").contains(marker))
        XCTAssertFalse(text("stdin").contains("setting.token"))
    }

    private func pressed(show: String) throws -> SpotRun {
        try script(toml: "[actions.note]\ninputs.value = \"text\"\n\n[actions.join]\ninputs.item = \"text\"", """
        . "$OPENSPOT_SH"
        case "$1" in
          show) printf '\(show)' ;;
          *) printf '%s %s|' "$*" "$(value value)$(value item)" >> '\(path("pressed"))' ;;
        esac
        """)
        return try sheet()
    }

    func testAChangeOfAFieldThatNamesAnActionPassesItsValueAsAnInput() async throws {
        let sheet = try pressed(show: "frame=\\nclass=gap-part\\n\\nfield=note\\nvalue=\\n")
        sheet.open {}
        try await wait("the field") { sheet.panel != nil && !sheet.isShowing }

        sheet.set(try XCTUnwrap(sheet.panel?.parts.first), to: "hello")

        try await wait("the note") { self.text("pressed").contains("note hello|") }
    }

    func testAnActionOnARowThatNamesAnActionPassesTheItemAsAnInput() async throws {
        let sheet = try pressed(show: "text=a\\ntitle=A\\n")
        sheet.open {}
        try await wait("the row") { sheet.list.all.count == 1 && !sheet.isShowing }

        sheet.run(CommandAction(id: "join", title: "Join"), item: try XCTUnwrap(sheet.list.all.first))

        try await wait("the join") { self.text("pressed").contains("join a|") }
    }
}
