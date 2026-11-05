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

    private func writeCommand(kind: SpotKind, subtitle: String? = nil, read: SpotRead? = nil, _ body: String) throws -> PluginCommand {
        let url = folder.appendingPathComponent("command.sh")
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return PluginCommand(id: "test/Command", name: "Command", url: url, kind: kind, subtitle: subtitle, read: read)
    }

    private var marker: URL {
        folder.appendingPathComponent("marker")
    }

    func testReadsTheStateACommandPrintsWithNoArguments() async throws {
        let command = try writeCommand(kind: .toggle, read: .open, """
        [ -z "$1" ] && printf 'title=Focus\\ndetail=On\\non=true\\n'
        """)

        let state = try await command.state(timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Focus", subtitle: "On", on: true))
    }

    func testAStateKeepsWhatItLeavesOutFromTheHeader() async throws {
        let command = try writeCommand(kind: .toggle, subtitle: "Header", read: .open, "echo on=true")

        let state = try await command.state(timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Command", subtitle: "Header", on: true))
    }

    func testASpotWithNoReadShowsItsHeaderAndDoesNotRun() async throws {
        let command = try writeCommand(kind: .launch, subtitle: "Folder", "touch '\(marker.path)'")

        let opened = try await command.opened(timeout: 5)

        XCTAssertEqual(opened.state, SpotState(title: "Command", subtitle: "Folder"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testOpeningGivesTheKindAndTheActionsThatItPrints() async throws {
        let command = try writeCommand(kind: .launch, read: .open, """
        printf 'on=true\\n\\naction=open\\ntitle=Select\\n\\naction=copy\\ntitle=Copy\\n\\nrow=A\\nrun=a\\n'
        """)

        let opened = try await command.opened(timeout: 5)

        XCTAssertEqual(opened.command.kind, .list)
        XCTAssertEqual(opened.command.primary, "Select")
        XCTAssertEqual(opened.command.actions.map(\.id), ["copy"])
        XCTAssertEqual(opened.state.on, true)
    }

    func testReadsTheItemsACommandPrintsWithNoArguments() async throws {
        let command = try writeCommand(kind: .list, """
        [ -z "$1" ] && printf 'row=Safari\\nrun=/Safari.app\\n'
        """)

        let lines = try await command.items(timeout: 5)

        XCTAssertEqual(lines.items, [SpotItem(title: "Safari", run: "/Safari.app")])
    }

    func testPassesTheSearchToALiveList() async throws {
        let command = try writeCommand(kind: .list, """
        printf 'row=%s\\nrun=%s\\n' "$2" "$1"
        """)

        let lines = try await command.items(query: "rep", timeout: 5)

        XCTAssertEqual(lines.items, [SpotItem(title: "rep", run: "search")])
    }

    func testReadsTheFormACommandPrints() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1 $2" = "form new" ] && printf 'title=New\\n\\nfield=title\\nlabel=Name\\n'
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
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "title=One\n")
    }

    func testOutputThatIsNotAStateFails() async throws {
        let command = try writeCommand(kind: .toggle, read: .open, "echo nonsense")

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

    func testAnActionCanPrintAToast() async throws {
        let quiet = try writeCommand(kind: .launch, "echo done > /dev/null")
        let quietToast = try await quiet.perform(.run, timeout: 5)
        let loud = try writeCommand(kind: .launch, "echo 'toast=All done'")
        let loudToast = try await loud.perform(.run, timeout: 5)

        XCTAssertNil(quietToast)
        XCTAssertEqual(loudToast, "All done")
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
