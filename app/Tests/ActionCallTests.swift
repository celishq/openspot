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
    outputs.took = "text"
    inputs.code = { type = "number", required = true }
    inputs.size = { type = "choice", options = ["s", "m"], default = "m" }

    [actions.wrong]
    outputs.code = "number"

    [actions.broken]
    """

    private enum Mode: CaseIterable {
        case once, stay, inline
    }

    private func text(_ name: String) -> String {
        (try? String(contentsOfFile: path(name), encoding: .utf8)) ?? ""
    }

    private func spot(_ mode: Mode = .once) throws -> SpotRun {
        switch mode {
        case .once, .stay:
            try script("\(mode)", toml: (mode == .stay ? "stay = true\n" : "") + Self.toml, """
            . "$OPENSPOT_SH"
            main() {
              echo "$1" >> '\(path("called-\(mode)"))'
              openspot_input > '\(path("stdin"))'
              case "$1" in
                make) echo "out.code=42" ;;
                take) printf 'out.took=%s %s\\n' "$(value code)" "$(value size)" ;;
                wrong) echo "out.code=many" ;;
                broken) printf 'error=The disk is full\\n' ;;
              esac
            }
            openspot_serve main "$@"
            """)
        case .inline:
            let url = folder.spotFile("\(mode)", extension: "js")
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try """
            export default {
              make() { return { code: 42 } },
              take({ code, size }) { return { took: `${code} ${size}` } },
              wrong() { return { code: "many" } },
              broken() { return "error=The disk is full\\n" },
            }
            """.write(to: url, atomically: true, encoding: .utf8)
            try Self.toml.write(to: url.deletingLastPathComponent().appendingPathComponent(Manifest.fileName), atomically: true, encoding: .utf8)
        }
        return try sheet("\(mode)")
    }

    func testAnActionTakesAnInputReadFromTheRealOutputOfAnotherInEachMode() async throws {
        for mode in Mode.allCases {
            let sheet = try spot(mode)

            let made = try await sheet.call("make")
            let took = try await sheet.call("take", inputs: made)

            XCTAssertEqual(made, [TextBlock.Field(key: "code", value: "42")], "\(mode)")
            XCTAssertEqual(took, [TextBlock.Field(key: "took", value: "42 m")], "\(mode)")
            if mode == .once { XCTAssertTrue(text("stdin").contains("input.code=42\ninput.size=m\n"), text("stdin")) }
        }
    }

    func testAnInputOfTheWrongTypeOrAMissingRequiredOneFailsBeforeTheCallInEachMode() async throws {
        for mode in Mode.allCases {
            let sheet = try spot(mode)

            for inputs in [[TextBlock.Field(key: "code", value: "many")], [], [.init(key: "code", value: "1"), .init(key: "size", value: "xl")]] {
                do {
                    let took = try await sheet.call("take", inputs: inputs)
                    XCTFail("\(mode) \(inputs) should fail, and gave \(took)")
                } catch {
                    XCTAssertTrue(SpotsModel.reason(error).contains(inputs.last?.key ?? "code"), "\(mode) \(SpotsModel.reason(error))")
                }
            }
            XCTAssertFalse(log("called-\(mode)").contains("take"), "\(mode)")
        }
    }

    func testAnOutputOfTheWrongTypeAndAnErrorInTheRootFailTheCallInEachMode() async throws {
        for mode in Mode.allCases {
            let sheet = try spot(mode)

            for (action, reason) in [("wrong", "code"), ("broken", "The disk is full")] {
                do {
                    let given = try await sheet.call(action)
                    XCTFail("\(mode) \(action) should fail, and gave \(given)")
                } catch {
                    XCTAssertTrue(SpotsModel.reason(error).contains(reason), "\(mode) \(SpotsModel.reason(error))")
                }
            }
        }
    }

    func testAGlobalKeyOnAnActionWithAMissingInputFailsWithALineThatNamesItInEachMode() async throws {
        for mode in Mode.allCases {
            let sheet = try spot(mode)
            var failures: [String] = []
            sheet.onReport = { if case .toast(let note) = $0, note.kind == .failure, note.fix == nil { failures.append(note.words) } }

            sheet.pressKey("take")

            try await wait("the failure of \(mode)") { !failures.isEmpty }
            XCTAssertEqual(failures.count, 1, "\(mode)")
            XCTAssertTrue(failures.first?.hasSuffix("take needs code, which is a number.") == true, "\(mode) \(failures)")
            XCTAssertFalse(log("called-\(mode)").contains("take"), "\(mode)")
        }
    }

    func testEachCallGetsThePlainSettingsAndNeverASecret() async throws {
        let store = SecretStore(file: folder.appendingPathComponent("secrets.json"))
        try store.keep(marker, key: "token", of: "once")
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
