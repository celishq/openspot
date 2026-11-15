import XCTest
@testable import OpenspotCore

@MainActor
final class SpotTablesTests: XCTestCase {
    private var folder: URL!

    override func setUp() async throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-tables-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func fault(ofHeader header: String) -> String? {
        do {
            _ = try SpotFile(script: URL(fileURLWithPath: "/none/probe.sh"), header: SpotHeader(text: "#!/bin/sh\n" + header).block, id: "probe")
            return nil
        } catch {
            return (error as? SpotError)?.reason
        }
    }

    private func findings(_ script: String) async throws -> [String] {
        try script.writeScript(to: folder.spotFile("probe"))
        return await SpotCheck(folder: SpotsFolder(url: folder)).findings().map(\.fault)
    }

    func testAHeaderKeyThatOpenspotDoesNotKnowIsAFault() {
        XCTAssertEqual(fault(ofHeader: "# titel=Coffee\n# on=sheet.open\n"), "Probe has an unknown key in its header: titel")
        XCTAssertNil(fault(ofHeader: "# title=Coffee\n# on=sheet.open\n# pages=day:*\n"))
    }

    func testACommentInAHeaderThatIsNoKeyOfTheContractDoesNotStopTheSpot() {
        XCTAssertNil(fault(ofHeader: "# title=T\n# shellcheck disable=SC2034\n# vim: set ts=2:\n# Set CITY=Paris to change it\n# on=sheet.open\n"))
        XCTAssertNil(fault(ofHeader: "# title=T\n#\n# button=go\n# title=Go\n# shellcheck disable=SC2034\n"))
        XCTAssertEqual(fault(ofHeader: "# title=T\n# read-on=sheet.open\n"), "T has an unknown key in its header: read-on")
    }

    func testAKeyThatAHeaderBlockDoesNotTakeIsAFault() {
        XCTAssertEqual(fault(ofHeader: "# title=T\n#\n# button=go\n# title=Go\n# colour=red\n"), "T has an unknown key on the button go: colour")
        XCTAssertEqual(fault(ofHeader: "# title=T\n#\n# field=look\n# titel=Look\n"), "T has an unknown key on the field look: titel")
    }

    func testAHeaderFieldThatAsksForAHotkeyIsAFault() {
        XCTAssertEqual(
            fault(ofHeader: "# title=T\n# on=sheet.open\n#\n# field=key\n# type=hotkey\n# title=Shortcut\n"),
            "T has an unknown key on the field key: type"
        )
    }

    func testARowHoldsKeysOfItsOwnWhichACheckDoesNotReport() async throws {
        let faults = try await findings("#!/bin/sh\n# on=sheet.open\nprintf 'row=a\\ntitle=A\\nruns=38\\n\\nrow=b\\ntitle=B\\npush.replace=true\\n'\n")

        XCTAssertEqual(faults, [])
    }

    func testAHeadKeyThatOpenspotDoesNotKnowIsReportedByACheck() async throws {
        let faults = try await findings("#!/bin/sh\n# on=sheet.open\nprintf 'title=T\\ntoost=Saved\\n\\nrow=a\\ntitle=A\\n'\n")

        XCTAssertEqual(faults, ["the head has an unknown key: toost"])
    }

    func testOnlyShownInTheHeadOfASpotOfTheAppMovesItsCardOnOrOffTheGrid() throws {
        let spot = Spot(id: "u", name: "U", url: URL(fileURLWithPath: "/none/u.sh"), read: .panel)

        XCTAssertFalse(try spot.builtIn().state(of: SpotOutput(text: "title=U\nshown=false\n")).isOnGrid)
        XCTAssertTrue(try spot.builtIn().state(of: SpotOutput(text: "title=U\nshown=true\n")).isOnGrid)
        XCTAssertTrue(try spot.builtIn().state(of: SpotOutput(text: "title=U\ngrid=false\n")).isOnGrid)
        XCTAssertTrue(try spot.state(of: SpotOutput(text: "title=U\nshown=false\n")).isOnGrid)
    }

    func testANewKindOfBlockIsOneValueOfTheTable() {
        let meter = BlockKind(
            name: "meter",
            keys: ["steps"],
            holdsValue: true,
            control: { .number($0.value("value") ?? "", unit: "steps") },
            faults: { $0.value("steps") == "0" ? ["the part \($0.fields.first?.value ?? "") needs a step"] : [] },
            data: { ($0.number("value"), nil) },
            field: { block, name, label in ItemForm.Field(name: name, label: label, value: block.value("value")) }
        )
        let frame = "title=T\n\nmeter=m\ntitle=M\nvalue=3\nsteps=0\ncolour=red\n"

        let check = FrameCheck(text: frame, kinds: BlockKind.all + [meter])

        XCTAssertEqual(check.output.parts.map(\.kind), ["meter"])
        XCTAssertEqual(check.output.parts.first?.control, .number("3", unit: "steps"))
        XCTAssertEqual(check.partFaults, ["the part m has an unknown key: colour", "the part m needs a step"])
        XCTAssertEqual(check.output.metric?.value("value"), "3")
        XCTAssertEqual(ItemForm(output: check.output)?.fields.map(\.name), ["m"])
        XCTAssertTrue(check.output.isPicture)
        XCTAssertEqual(SpotOutput(text: frame).errors, ["meter=m"])
    }

    func testABlockIsReadByTheKindThatItsWordAndItsTypeName() {
        let output = SpotOutput(text: "graph=one\nvalue=0.5\n\ngraph=bars\nvalue=1\nvalue=2\n\nfield=level\ntype=slider\n\nfield=key\ntype=hotkey\n\nfield=name\n\nswitch=done\ntype=tick\n")

        XCTAssertEqual(output.parts.map(\.kind), ["gauge", "graph", "slider", "hotkey", "field", "switch"])
        XCTAssertEqual(output.parts.last?.look, .tick)
        XCTAssertEqual(output.fields.map(\.kind.name), ["slider", "field", "switch"])
        XCTAssertEqual(BlockKind.words, ["text", "number", "graph", "picture", "view", "switch", "field", "choice", "option", "button", "section", "repeat", "row"])
    }

    private func unknownKeys(in frame: String) -> [String] {
        let check = FrameCheck(text: frame)
        return check.output.isPicture ? check.partFaults.filter { $0.contains("has an unknown key") } : []
    }

    func testEachSheetExampleAndEachFrameOfTheDocsHoldsOnlyKeysOfTheTables() throws {
        for example in SheetExamples.all + [SheetExamples.tiles] {
            XCTAssertEqual(FrameCheck(text: example.text).partFaults, [], example.name)
        }
        for doc in try ["GUIDE.md", "PROTOCOL.md"].map(RepoDoc.init) + RepoDoc.all().filter({ $0.path.hasPrefix("app/Help/") }) {
            for fence in doc.fences where fence.language == "ini" {
                for frame in fence.text.components(separatedBy: "\n\(SheetFrames.mark)") {
                    XCTAssertEqual(unknownKeys(in: frame), [], "\(doc.path): \(frame.prefix(60))")
                }
            }
        }
    }

    func testEachSampleOfASpotAndOfAnExampleHoldsOnlyKeysOfTheTables() async throws {
        for name in ["spots", "examples"] {
            for spot in try SpotsFolder(url: RepoDoc.repo.appendingPathComponent(name)).scan().scripts {
                guard let sampled = spot.sampled else { continue }
                let frame = try await SpotRuns(environment: TestEnvironment.values).answer(of: sampled, .read, limit: 60)
                XCTAssertEqual(unknownKeys(in: frame), [], spot.id)
            }
        }
    }

    func testTheAccountUseOnASpotThatDoesNotShipInOpenspotIsReportedByACheck() async throws {
        let faults = try await findings("#!/bin/sh\n# title=Mine\n# uses=account, network\n")

        XCTAssertEqual(faults, ["Mine has uses=account, which only a spot of Openspot takes. Remove it"])
    }
}
