import XCTest
@testable import OpenspotCore

final class SpotTests: XCTestCase {
    private func dataName(id: String, header: [TextBlock.Field] = []) throws -> String? {
        try SpotFile(script: URL(fileURLWithPath: "/p/\(id).sh"), header: TextBlock(fields: header), id: id).spots.first?.dataName
    }

    func testTheDataFolderOfASpotIsItsName() throws {
        XCTAssertEqual(try dataName(id: "links"), "links")
    }

    func testScriptsInOneFolderShareItsDataFolder() throws {
        XCTAssertEqual(try dataName(id: "home/coffee"), "home")
    }

    func testADataKeyRefusesThePluginAndSaysThatAFolderSharesItsData() throws {
        XCTAssertThrowsError(try dataName(id: "links", header: [.init(key: "data", value: "notes")])) { error in
            XCTAssertTrue((error as? SpotError)?.reason.contains("OPENSPOT_DATA") == true, "\(error)")
        }
    }

    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("openspot-plugin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func writeCommand(kind: SpotKind, subtitle: String? = nil, read: SpotRead? = nil, _ body: String) throws -> Spot {
        let url = folder.appendingPathComponent("command.sh")
        try "#!/bin/sh\n\(body)\n".writeScript(to: url)
        return Spot(id: "test/Command", name: "Command", url: url, kind: kind, subtitle: subtitle, read: read)
    }

    private var marker: URL {
        folder.appendingPathComponent("marker")
    }

    func testReadsTheStateACommandPrintsForRead() async throws {
        let command = try writeCommand(kind: .toggle, read: .panel, """
        [ "$1" = read ] && [ -z "$2" ] && printf 'switch=focus\\ntitle=Focus\\ndetail=On\\nvalue=true\\n'
        """)

        let state = try await command.state(timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Focus", subtitle: "On", on: true, control: "focus"))
    }

    func testOnlyASpotWithAViewKeepsTheValuesOfItsViewBlock() throws {
        let output = SpotOutput(text: "view=cups\ntitle=3\npoint=1\npoint=2\n")
        let plain = Spot(id: "cups", name: "Cups", url: URL(fileURLWithPath: "/plugins/cups.sh"), read: .panel)
        let drawn = Spot(id: "cups", name: "Cups", url: URL(fileURLWithPath: "/plugins/cups.sh"), read: .panel, view: "/plugins/cups.swift")

        XCTAssertEqual(try plain.state(of: output).values, [:])
        XCTAssertEqual(try drawn.state(of: output).values, ["view": ["cups"], "title": ["3"], "point": ["1", "2"]])
        XCTAssertTrue(try drawn.state(of: output).face.hasView)
    }

    func testAStateKeepsWhatItLeavesOutFromTheHeader() async throws {
        let command = try writeCommand(kind: .toggle, subtitle: "Header", read: .panel, "printf 'switch=power\\nvalue=true\\n'")

        let state = try await command.state(timeout: 5)

        XCTAssertEqual(state, SpotState(title: "Command", subtitle: "Header", on: true, control: "power"))
    }

    func testASpotWithNoReadShowsItsHeaderAndDoesNotRun() async throws {
        let command = try writeCommand(kind: .launch, subtitle: "Folder", "touch '\(marker.path)'")

        let opened = try await command.opened(timeout: 5)

        XCTAssertEqual(opened.state, SpotState(title: "Command", subtitle: "Folder"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    func testOpeningGivesTheKindAndTheActionsThatItPrints() async throws {
        let command = try writeCommand(kind: .launch, read: .panel, """
        printf 'switch=power\\nvalue=true\\n\\nbutton=open\\ntitle=Select\\n\\nbutton=copy\\ntitle=Copy\\n\\nrow=a\\ntitle=A\\n'
        """)

        let opened = try await command.opened(timeout: 5)

        XCTAssertEqual(opened.spot.kind, .list)
        XCTAssertEqual(opened.spot.primary, "Select")
        XCTAssertEqual(opened.spot.actions.map(\.id), ["copy"])
        XCTAssertEqual(opened.state.on, true)
    }

    func testReadsTheItemsACommandPrintsForRead() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1" = read ] && [ -z "$2" ] && printf 'row=/Safari.app\\ntitle=Safari\\n'
        """)

        let lines = try await command.items(timeout: 5)

        XCTAssertEqual(lines.items, [SpotItem(title: "Safari", run: "/Safari.app")])
    }

    func testPassesTheSearchToAList() async throws {
        let command = try writeCommand(kind: .list, """
        printf 'row=%s\\ntitle=%s\\n' "$1" "$(sed -n 's/^search=//p')"
        """)

        let lines = try await command.items(query: "rep", timeout: 5)

        XCTAssertEqual(lines.items, [SpotItem(title: "rep", run: "read")])
    }

    func testAFormIsTheCallOfItsActionWithEmptyStdin() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1" = new ] && [ -z "$(cat)" ] && printf 'title=New\\n\\nfield=title\\ntitle=Name\\n'
        """)

        let form = try await command.form(CommandAction(id: "new", title: "New", isForm: true), item: nil, timeout: 5)

        XCTAssertEqual(form, ItemForm(title: "New", fields: [.init(name: "title", label: "Name")]))
    }

    func testAFormOfARowGetsTheRunOfThatRow() async throws {
        let command = try writeCommand(kind: .list, """
        [ "$1 $2" = "edit one" ] && printf 'title=Edit\\n\\nfield=title\\ntitle=Name\\n'
        """)

        let form = try await command.form(CommandAction(id: "edit", title: "Edit", isForm: true), item: SpotItem(title: "One", run: "one"), timeout: 5)

        XCTAssertEqual(form.title, "Edit")
    }

    func testAClickOnAFileWithNoReadSendsOpen() async throws {
        let command = try writeCommand(kind: .launch, "echo \"$1\" > '\(marker.path)'")

        try await command.perform(command.click, timeout: 5)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "open\n")
    }

    func testAClickOnACardWithAReadSendsOpen() async throws {
        let command = try writeCommand(kind: .launch, read: .panel, "echo \"$1\" > '\(marker.path)'")

        try await command.perform(command.click, timeout: 5)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "open\n")
    }

    func testAFormThatCannotBeReadFails() async throws {
        let command = try writeCommand(kind: .list, "echo nonsense")

        do {
            _ = try await command.form(CommandAction(id: "new", title: "New", isForm: true), item: nil, timeout: 5)
            XCTFail("expected a failure")
        } catch SpotError.badForm {
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
        let command = try writeCommand(kind: .toggle, read: .panel, "echo nonsense")

        do {
            _ = try await command.state(timeout: 5)
            XCTFail("expected a failure")
        } catch SpotError.badState {
        }
    }

    func testPerformPassesTheActionArguments() async throws {
        let command = try writeCommand(kind: .toggle, "echo \"$*\" > '\(marker.path)'")

        try await command.perform(.toggle(SpotState(title: "Focus", on: false, control: "focus")), timeout: 5)

        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "focus true\n")
    }

    func testAnActionCanPrintAToast() async throws {
        let quiet = try writeCommand(kind: .launch, "echo done > /dev/null")
        let quietToast = try await quiet.perform(quiet.click, timeout: 5)
        let loud = try writeCommand(kind: .launch, "echo 'toast=All done'")
        let loudToast = try await loud.perform(loud.click, timeout: 5)

        XCTAssertNil(quietToast)
        XCTAssertEqual(loudToast, "All done")
    }

    func testAFailureCarriesTheLastLineOfItsErrorOutput() async throws {
        let command = try writeCommand(kind: .launch, "echo first >&2\necho 'No screenshot found.' >&2\nexit 3")

        do {
            try await command.perform(command.click, timeout: 5)
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
