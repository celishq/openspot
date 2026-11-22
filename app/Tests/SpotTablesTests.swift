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

    private func fault(of toml: String) -> String? {
        do {
            _ = try SpotFile(script: URL(fileURLWithPath: "/none/probe.sh"), manifest: Manifest(text: toml, folder: "/none").script("probe.sh"), id: "probe")
            return nil
        } catch {
            return (error as? SpotError)?.reason
        }
    }

    private func findings(_ script: String, toml: String = "") async throws -> [String] {
        try script.writeScript(to: folder.spotFile("probe"), toml: toml)
        return await SpotCheck(folder: SpotsFolder(url: folder)).findings().map(\.fault)
    }

    func testAKeyThatOpenspotDoesNotKnowIsAFault() {
        XCTAssertEqual(fault(of: "titel = 'Coffee'"), "Probe has an unknown key in its spot.toml: titel")
        XCTAssertEqual(fault(of: "title = 'T'\nTitle = 'U'"), "T has an unknown key in its spot.toml: Title")
        XCTAssertEqual(fault(of: "title = 'T'\n[look]\ncolour = 'red'"), "T has an unknown key in its spot.toml: look")
        XCTAssertNil(fault(of: "title = 'Coffee'\npages = ['day:*']\n# Set CITY=Paris to change it"))
    }

    func testAKeyThatACommandOrASettingDoesNotTakeIsAFault() {
        XCTAssertEqual(fault(of: "title = 'T'\n[commands.go]\ntitle = 'Go'\ncolour = 'red'"), "T has an unknown key in [commands.go]: colour")
        XCTAssertEqual(fault(of: "title = 'T'\n[settings.look]\ntitel = 'Look'"), "T has an unknown key in [settings.look]: titel")
    }

    func testASpotTomlThatCannotBeReadIsAFaultThatNamesItsLine() {
        XCTAssertEqual(fault(of: "title = 'T'\non sheet.open"), "Probe cannot load: spot.toml, line 2: expected a key and a value")
    }

    func testASettingThatAsksForAHotkeyIsAFault() {
        XCTAssertEqual(
            fault(of: "title = 'T'\n[settings.key]\ntype = 'hotkey'\ntitle = 'Shortcut'"),
            "T has an unknown type in [settings.key]: `hotkey`. Use `type = \"secret\"`, or no type."
        )
        XCTAssertNil(fault(of: "title = 'T'\n[settings.token]\ntype = 'secret'"))
    }

    func testARowHoldsKeysOfItsOwnWhichACheckDoesNotReport() async throws {
        let faults = try await findings("#!/bin/sh\nprintf 'item=a\\ntitle=A\\nruns=38\\n\\nitem=b\\ntitle=B\\npush.replace=true\\n'\n", toml: "")

        XCTAssertEqual(faults, [])
    }

    func testARootKeyThatOpenspotDoesNotKnowIsReportedByACheck() async throws {
        let faults = try await findings("#!/bin/sh\nprintf 'frame=\\ntitle=T\\ntoost=Saved\\n\\nitem=a\\ntitle=A\\n'\n", toml: "")

        XCTAssertEqual(faults, ["the root has an unknown key: toost"])
    }

    func testShownIsAnUnknownRootKeyOutsideTheSpotsOfTheApp() async throws {
        let faults = try await findings("#!/bin/sh\nprintf 'frame=\\ntitle=T\\nshown=false\\n'\n", toml: "on = ['clock.600']")

        XCTAssertEqual(faults, ["the root has an unknown key: shown"])
        XCTAssertEqual(FrameCheck(text: "frame=\ntitle=T\nshown=false\n", isApp: true).partFaults, [])
    }

    func testOnlyShownInTheHeadOfASpotOfTheAppMovesItsCardOnOrOffTheGrid() throws {
        let spot = Spot(id: "u", name: "U", url: URL(fileURLWithPath: "/none/u.sh"), on: .panel)

        XCTAssertFalse(try spot.builtIn().state(of: Frame(text: "frame=\ntitle=U\nshown=false\n")).isOnGrid)
        XCTAssertTrue(try spot.builtIn().state(of: Frame(text: "frame=\ntitle=U\nshown=true\n")).isOnGrid)
        XCTAssertTrue(try spot.builtIn().state(of: Frame(text: "frame=\ntitle=U\ngrid=false\n")).isOnGrid)
        XCTAssertTrue(try spot.state(of: Frame(text: "frame=\ntitle=U\nshown=false\n")).isOnGrid)
    }

    func testANewKindOfBlockIsOneValueOfTheTable() {
        let meter = BlockKind(
            name: "meter",
            keys: ["steps"],
            holdsValue: true,
            isReading: true,
            control: { .number(NumberReading(block: $0)) },
            faults: { $0.value("steps") == "0" ? ["the part \($0.fields.first?.value ?? "") needs a step"] : [] },
            field: { block, name, label in ItemForm.Field(name: name, label: label, value: block.value("value")) }
        )
        let frame = "frame=\ntype=form\ntitle=T\nclass=gap-part\n\nmeter=m\ntitle=M\nvalue=3\nsteps=0\ncolour=red\n"

        let check = FrameCheck(text: frame, kinds: BlockKind.all + [meter])

        XCTAssertEqual(check.output.parts.map(\.kind), ["meter"])
        XCTAssertEqual(check.output.parts.first?.number?.text, "3")
        XCTAssertEqual(check.partFaults, ["the part m has an unknown key: colour", "the part m needs a step"])
        XCTAssertEqual(check.output.metric?.value("value"), "3")
        XCTAssertEqual(ItemForm(output: check.output)?.fields.map(\.name), ["m"])
        XCTAssertTrue(check.output.isPicture)
        XCTAssertEqual(Frame(text: frame).errors, ["meter=m"])
    }

    func testABlockIsReadByTheKindThatItsWordAndItsTypeName() {
        let output = Frame(text: "frame=\nclass=gap-part\n\nnumber=one\nvalue=0.5\nmax=1\n\nseries=bars\nvalue=1,2\n\nfield=level\ntype=slider\n\nfield=key\ntype=hotkey\n\nfield=name\n\nswitch=done\ntype=tick\n")

        XCTAssertEqual(output.parts.map(\.kind), ["number", "series", "slider", "hotkey", "field", "switch"])
        XCTAssertEqual(output.parts.last?.isTick, true)
        XCTAssertEqual(output.fields.map(\.kind.name), ["slider", "field", "switch"])
        XCTAssertEqual(BlockKind.words, ["text", "item", "number", "series", "picture", "icon", "switch", "field", "choice", "option", "button", "items", "box"])
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
                let frame = try await SpotRuns(environment: TestEnvironment.values).answer(of: sampled, .show, limit: 60)
                XCTAssertEqual(unknownKeys(in: frame), [], spot.id)
            }
        }
    }

    func testTheAccountUseOnASpotThatDoesNotShipInOpenspotIsReportedByACheck() async throws {
        let faults = try await findings("#!/bin/sh\n", toml: "title = 'Mine'\nuses = ['account', 'network']")

        XCTAssertEqual(faults, ["Mine has account in its uses, which only a spot of Openspot takes. Remove it"])
    }
}
