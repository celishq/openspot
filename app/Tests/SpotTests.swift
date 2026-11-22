import XCTest
@testable import OpenspotCore

final class SpotTests: XCTestCase {
    private func dataName(id: String) throws -> String? {
        try SpotFile(script: URL(fileURLWithPath: "/p/\(id).sh"), manifest: Manifest(text: nil, folder: "/p"), id: id).spots.first?.dataName
    }

    func testTheDataFolderOfASpotIsItsName() throws {
        XCTAssertEqual(try dataName(id: "links"), "links")
    }

    func testScriptsInOneFolderShareItsDataFolder() throws {
        XCTAssertEqual(try dataName(id: "home/coffee"), "home")
    }

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-spot-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writeCommand(kind: SpotKind, subtitle: String? = nil, on: ShowEvents? = nil, _ body: String) throws -> Spot {
        let url = folder.appendingPathComponent("command.sh")
        try "#!/bin/sh\n\(body)\n".writeScript(to: url)
        return Spot(id: "test/Command", name: "Command", url: url, kind: kind, subtitle: subtitle, on: on)
    }

    private var marker: URL {
        folder.appendingPathComponent("marker")
    }

    func testReadsTheStateACommandPrintsForRead() async throws {
        let command = try writeCommand(kind: .toggle, on: .panel, """
        [ "$1" = show ] && [ -z "$2" ] && printf 'switch=focus\\ntitle=Focus\\ndetail=On\\nvalue=true\\nclass=card:flex\\n'
        """)

        let state = try await command.state(timeout: 60)

        XCTAssertEqual([state.title, state.subtitle, state.control], ["Command", nil, "focus"])
        XCTAssertEqual(state.on, true)
    }

    func testAStateKeepsWhatItLeavesOutFromTheHeader() async throws {
        let command = try writeCommand(kind: .toggle, subtitle: "Header", on: .panel, "printf 'switch=power\\nvalue=true\\nclass=card:flex\\n'")

        let state = try await command.state(timeout: 60)

        XCTAssertEqual([state.title, state.subtitle, state.control], ["Command", "Header", "power"])
        XCTAssertEqual(state.on, true)
    }

    func testASpotWithNoReadShowsItsHeaderAndDoesNotRun() async throws {
        let command = try writeCommand(kind: .launch, subtitle: "Folder", "touch '\(marker.path)'")

        let opened = try await command.opened(timeout: 60)

        XCTAssertEqual(opened.state, SpotState(title: "Command", subtitle: "Folder"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testOpeningGivesTheKindAndTheActionsThatItPrints() async throws {
        let command = try writeCommand(kind: .launch, on: .panel, """
        printf 'frame=\\nactive=true\\n\\nbutton=open\\ntitle=Select\\n\\nbutton=copy\\ntitle=Copy\\n\\ntext=a\\ntitle=A\\n'
        """)

        let opened = try await command.opened(timeout: 60)

        XCTAssertEqual(opened.spot.kind, .list)
        XCTAssertEqual(opened.spot.openTitle, "Select")
        XCTAssertEqual(opened.spot.actions.map(\.id), ["copy"])
        XCTAssertEqual(opened.state.on, true)
    }

    func testReadsTheItemsACommandPrintsForRead() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1" = show ] && [ -z "$2" ] && printf 'text=/Safari.app\\ntitle=Safari\\n'
        """)

        let lines = try await command.items(timeout: 60)

        XCTAssertEqual(lines.items, [SpotItem(title: "Safari", run: "/Safari.app")])
    }

    func testPassesTheSearchToAList() async throws {
        let command = try writeCommand(kind: .list, """
        printf 'text=%s\\ntitle=%s\\n' "$1" "$(sed -n 's/^search=//p')"
        """)

        let lines = try await command.items(query: "rep", timeout: 60)

        XCTAssertEqual(lines.items, [SpotItem(title: "rep", run: "show")])
    }

    func testAFormIsTheCallOfItsActionWithEmptyStdin() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1" = new ] && [ -z "$(cat)" ] && printf 'frame=\\ntype=form\\ntitle=New\\n\\nfield=title\\ntitle=Name\\n'
        """)

        let form = try await command.form(CommandAction(id: "new", title: "New", isForm: true), item: nil, timeout: 60)

        XCTAssertEqual(form, ItemForm(title: "New", fields: [.init(name: "title", label: "Name")]))
    }

    func testAFormOfARowGetsTheRunOfThatRow() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1 $2" = "edit one" ] && printf 'frame=\\ntype=form\\ntitle=Edit\\n\\nfield=title\\ntitle=Name\\n'
        """)

        let form = try await command.form(CommandAction(id: "edit", title: "Edit", isForm: true), item: SpotItem(title: "One", run: "one"), timeout: 60)

        XCTAssertEqual(form.title, "Edit")
    }

    func testAClickOnAFileWithNoReadSendsOpen() async throws {
        let command = try writeCommand(kind: .launch, "echo \"$1\" > '\(marker.path)'")

        try await command.perform(command.click, timeout: 60)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "open\n")
    }

    func testAClickOnACardWithAReadSendsOpen() async throws {
        let command = try writeCommand(kind: .launch, on: .panel, "echo \"$1\" > '\(marker.path)'")

        try await command.perform(command.click, timeout: 60)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "open\n")
    }

    func testAFormThatCannotBeReadFails() async throws {
        let command = try writeCommand(kind: .list, "echo nonsense")

        do {
            _ = try await command.form(CommandAction(id: "new", title: "New", isForm: true), item: nil, timeout: 60)
            XCTFail("expected a failure")
        } catch SpotError.badForm {
        }
    }

    func testSubmitGivesTheValuesOnStdin() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1" = new ] && cat > '\(marker.path)'
        """)
        let form = ItemForm(title: "New", fields: [.init(name: "title", label: "Name", value: "One")])

        try await command.submit(CommandAction(id: "new", title: "New", isForm: true), item: nil, draft: FormDraft(form: form), timeout: 60)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "input.title=One\n")
    }

    func testOutputThatIsNotAStateFails() async throws {
        let command = try writeCommand(kind: .toggle, on: .panel, "echo nonsense")

        do {
            _ = try await command.state(timeout: 60)
            XCTFail("expected a failure")
        } catch SpotError.badState {
        }
    }

    func testPerformPassesTheActionArguments() async throws {
        let command = try writeCommand(kind: .toggle, "echo \"$*\" > '\(marker.path)'")

        try await command.perform(.toggle(SpotState(title: "Focus", on: false, control: "focus")), timeout: 60)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "focus true\n")
    }

    func testAFailureCarriesTheLastLineOfItsErrorOutput() async throws {
        let command = try writeCommand(kind: .launch, "echo first >&2\necho 'No screenshot found.' >&2\nexit 3")

        do {
            try await command.perform(command.click, timeout: 60)
            XCTFail("expected a failure")
        } catch let error as SpotError {
            XCTAssertEqual(error, .failed(3, "No screenshot found."))
            XCTAssertEqual(error.reason, "No screenshot found.")
        }
    }

    func testASilentFailureNamesItsCode() {
        XCTAssertEqual(SpotError.failed(3, "").reason, "It stopped with code 3.")
    }

    func testATimeoutHasAPlainReason() {
        XCTAssertEqual(SpotError.timedOut.reason, "It took too long.")
    }
}
