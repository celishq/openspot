import XCTest
@testable import OpenspotCore

final class PluginCommandTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-plugin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writeCommand(kind: SpotKind, subtitle: String? = nil, hasState: Bool = false, _ body: String) throws -> PluginCommand {
        let url = folder.appendingPathComponent("command.sh")
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return PluginCommand(id: "test/Command", name: "Command", url: url, kind: kind, subtitle: subtitle, hasState: hasState)
    }

    private var marker: URL {
        folder.appendingPathComponent("marker")
    }

    func testReadsTheStateACommandPrints() async throws {
        let command = try writeCommand(kind: .toggle, """
        [ "$1" = state ] && echo '{"title":"Focus","subtitle":"On","on":true}'
        """)

        let state = try await command.state(timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Focus", subtitle: "On", on: true))
    }

    func testALaunchSpotShowsItsManifestAndDoesNotRun() async throws {
        let command = try writeCommand(kind: .launch, subtitle: "Folder", "touch '\(marker.path)'")

        let state = try await command.state(timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Command", subtitle: "Folder"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testAListShowsItsManifestUnlessItHasAState() async throws {
        let body = "echo '{\"title\":\"Read\"}'"

        let plain = try writeCommand(kind: .list, subtitle: "Apps", body)
        let plainState = try await plain.state(timeout: 5)
        let stated = try writeCommand(kind: .list, hasState: true, body)
        let statedState = try await stated.state(timeout: 5)

        XCTAssertEqual(plainState, SpotState(title: "Command", subtitle: "Apps"))
        XCTAssertEqual(statedState, SpotState(title: "Read"))
    }

    func testReadsTheItemsACommandPrints() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1" = items ] && echo '{"title":"Safari","run":"/Safari.app"}'
        """)

        let lines = try await command.items(timeout: 5)

        XCTAssertEqual(lines.items, [SpotItem(title: "Safari", run: "/Safari.app")])
    }

    func testPassesTheSearchToALiveList() async throws {
        let command = try writeCommand(kind: .list, """
        printf '{"title":"%s","run":"%s"}\\n' "$2" "$1"
        """)

        let lines = try await command.items(query: "rep", timeout: 5)

        XCTAssertEqual(lines.items, [SpotItem(title: "rep", run: "items")])
    }

    func testReadsTheFormACommandPrints() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1 $2" = "form new" ] && echo '{"title":"New","fields":[{"name":"title","label":"Name","type":"text"}]}'
        """)

        let form = try await command.form(CommandAction(id: "new", title: "New", isForm: true), item: nil, timeout: 5)

        XCTAssertEqual(form, ItemForm(title: "New", fields: [.init(name: "title", label: "Name")]))
    }

    func testAFormThatCannotBeReadFails() async throws {
        let command = try writeCommand(kind: .list, "echo nonsense")

        do {
            _ = try await command.form(CommandAction(id: "new", title: "New", isForm: true), item: nil, timeout: 5)
            XCTFail("expected a failure")
        } catch PluginError.badForm {
        }
    }

    func testSubmitGivesTheValuesAndReturnsTheNewRun() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1" = new ] && cat > '\(marker.path)' && echo ' abc '
        """)
        let form = ItemForm(title: "New", fields: [.init(name: "title", label: "Name", value: "One")])

        let run = try await command.submit(CommandAction(id: "new", title: "New", isForm: true), item: nil, draft: FormDraft(form: form), timeout: 5)

        XCTAssertEqual(run, "abc")
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), #"{"title":"One"}"#)
    }

    func testOutputThatIsNotAStateFails() async throws {
        let command = try writeCommand(kind: .toggle, "echo nonsense")

        do {
            _ = try await command.state(timeout: 5)
            XCTFail("expected a failure")
        } catch PluginError.badState {
        }
    }

    func testPerformPassesTheActionArguments() async throws {
        let command = try writeCommand(kind: .toggle, "echo \"$1\" > '\(marker.path)'")

        try await command.perform(.toggle(SpotState(title: "Focus", on: false)), timeout: 5)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "on\n")
    }

    func testAFailureCarriesTheLastLineOfItsErrorOutput() async throws {
        let command = try writeCommand(kind: .launch, "echo first >&2\necho 'No screenshot found.' >&2\nexit 3")

        do {
            try await command.perform(.run, timeout: 5)
            XCTFail("expected a failure")
        } catch let error as PluginError {
            XCTAssertEqual(error, .failed(3, "No screenshot found."))
            XCTAssertEqual(error.reason, "No screenshot found.")
        }
    }

    func testASilentFailureNamesItsCode() {
        XCTAssertEqual(PluginError.failed(3, "").reason, "It stopped with code 3.")
    }

    func testATimeoutHasAPlainReason() {
        XCTAssertEqual(PluginError.timedOut.reason, "It took too long.")
    }
}
