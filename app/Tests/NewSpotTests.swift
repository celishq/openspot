import XCTest
@testable import OpenspotCore

final class NewSpotTests: BuiltInCase {
    private var guideText = ""
    private var effects: (() -> [String])!
    private var repo: URL {
        repoSpots.deletingLastPathComponent()
    }

    override func setUp() async throws {
        try await super.setUp()
        guideText = try protocolGuide()
        try guideText.write(to: guide, atomically: true, encoding: .utf8)
        try fake("pbcopy", "cat > '\(root.path)/direct'")
        let real = tools.appendingPathComponent("openspot-real")
        try FileManager.default.moveItem(at: tools.appendingPathComponent("openspot"), to: real)
        try fake("openspot", "[ \"$1 $2\" = 'clipboard copy' ] && exec cat > '\(root.path)/clipboard'\nexec '\(real.path)' \"$@\"")
        try fake("open", "echo \"$@\" > '\(root.path)/opened'")
        effects = try recordEffects()
    }

    private func newSpot() throws -> Spot {
        try spot("new")
    }

    private func saved(_ name: String) throws -> String {
        try String(contentsOf: root.appendingPathComponent(name), encoding: .utf8)
    }

    func testItIsAListThatTheDefaultGridShowsAsAStripAndOpensWithCommandN() throws {
        let spot = try newSpot()
        let defaults = Config(text: try String(contentsOf: repo.appendingPathComponent("app/defaults.toml"), encoding: .utf8))

        XCTAssertEqual(spot.name, "New spot")
        XCTAssertEqual(spot.kind, .list)
        XCTAssertEqual(defaults.arrangement.size(of: spot.id), .strip)
        XCTAssertTrue(spot.isOnGrid)
        XCTAssertEqual(SpotArrangement().spot(openedBy: ActionKey(name: "n", isCommand: true), over: defaults.arrangement), spot.id)
    }

    func testTheSheetIsOneFieldToDescribeTheSpotAndACopyPromptButton() async throws {
        let output = try await newSpot().items(timeout: 60)

        XCTAssertEqual(output.parts.map(\.id), ["describe", "copy"])
        XCTAssertEqual(output.items, [])
        let field = try XCTUnwrap(output.parts.first)
        XCTAssertEqual(output.fields.map { $0.block.value("type") }, ["multiline"])
        XCTAssertEqual(field.control, .text("", placeholder: "Describe what you want to build", isReadOnly: false))
        let copy = try XCTUnwrap(output.parts.last)
        XCTAssertEqual(copy.title, "Copy prompt")
        XCTAssertEqual(output.tree.look(of: copy.id), .strong)
        XCTAssertEqual(copy.key, ActionKey(name: "return", isCommand: true))
        XCTAssertEqual(output.actions.map(\.title), ["Clear", "Read the guide", "Open spots folder"])
        XCTAssertEqual(SheetParts(output: output).hint(stopping: { _ in false }, actions: true), "⌘⏎ Copy prompt   ⌘K Actions")
    }

    func testTheFieldKeepsTheWordsThatThePersonTypesAcrossAReadAndACall() async throws {
        let spot = try newSpot()

        for action in [SpotWords(arguments: ["show"]), SpotWords(arguments: ["describe", "Show the weather"])] {
            let output = try await spot.answer(action, input: "input.describe=Show the weather\\nin Kyiv\n", timeout: 60)
            XCTAssertEqual(output.parts.first?.value, "Show the weather\nin Kyiv", "\(action.arguments)")
        }
    }

    func testEverySearchEndsWithARowThatMakesASpotOfTheTypedWords() async throws {
        let make = try newSpot()

        let rows = try await make.answer(SpotWords(arguments: ["search"]), input: "input.text= time in kyiv \n", timeout: 60).answers(asCard: false)

        XCTAssertEqual(try XCTUnwrap(make.triggers.search).isLast, true)
        XCTAssertEqual(rows.map(\.run), ["time in kyiv"])
        XCTAssertEqual(rows.map(\.title), ["Make a spot"])
        XCTAssertEqual(rows.map(\.subtitle), ["time in kyiv"])
    }

    func testAPickOfMakeASpotCopiesThePromptThatBuildsTheTypedWords() async throws {
        try await newSpot().perform(SpotWords(arguments: ["press"]), input: "input.item=time in kyiv\n", timeout: 60)

        XCTAssertEqual(effects(), ["toast \(AgentPrompt.copied)"])
        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasPrefix("Build an Openspot spot that does this: time in kyiv\n\(AgentPrompt.finishAlone)\n"), prompt)
    }

    func testAfterACopyTheNextOpenStartsEmpty() async throws {
        let spot = try newSpot()

        try await spot.perform(.press("copy"), input: "input.describe=Show the weather\n", timeout: 60)

        XCTAssertEqual(effects(), ["toast \(AgentPrompt.copied)"])
        let reopened = try await spot.answer(.show, timeout: 60)
        XCTAssertEqual(reopened.parts.first?.value ?? "", "")
    }

    func testTheWordsStayAsADraftWhenTheSheetClosesAndClearEmptiesThem() async throws {
        let spot = try newSpot()
        _ = try await spot.answer(SpotWords(arguments: ["describe", "A list of my repos"]), input: "input.describe=A list of my repos\n", timeout: 60)

        let reopened = try await spot.answer(.show, timeout: 60)
        XCTAssertEqual(reopened.parts.first?.value, "A list of my repos")

        let cleared = try await spot.answer(SpotWords(arguments: ["clear"]), input: "input.describe=A list of my repos\n", timeout: 60)
        XCTAssertEqual(cleared.parts.first?.value ?? "", "")
        let again = try await spot.answer(.show, timeout: 60)
        XCTAssertEqual(again.parts.first?.value ?? "", "")
        XCTAssertEqual(again.actions.map(\.title), ["Clear", "Read the guide", "Open spots folder"])
    }

    func testCopyPromptWithWordsCopiesThePromptThatBuildsTheSpotToTheEnd() async throws {
        let spot = try newSpot()

        try await spot.perform(.press("copy"), input: "input.describe=Show the weather\\nin Kyiv\n", timeout: 60)

        XCTAssertEqual(effects(), ["toast \(AgentPrompt.copied)"])
        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasPrefix("Build an Openspot spot that does this: Show the weather\nin Kyiv\n\(AgentPrompt.finishAlone)\n"), prompt)
        XCTAssertTrue(prompt.contains(spots.path))
        XCTAssertEqual(try SpotsFolder(url: spots).scan().spots, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("opened").path))
    }

    func testCopyPromptWithAnEmptyFieldCopiesThePromptThatAsksWhatToBuild() async throws {
        try await newSpot().perform(.press("copy"), input: "input.describe=  \n", timeout: 60)

        XCTAssertEqual(effects(), ["toast \(AgentPrompt.copied)"])
        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasPrefix("Help me build an Openspot spot. Start by asking me what the spot should do"), prompt)
        XCTAssertFalse(prompt.contains("Build an Openspot spot that does this"))
    }

    func testTheWordsOfTheFieldReachThePressAndTheButtonSaysCopiedThenCopyPromptAgain() async throws {
        let runs = SpotRuns(environment: TestEnvironment.values)
        defer { runs.quit() }
        let sheet = runs.sheet(for: try newSpot())
        sheet.open {}
        for _ in 0..<6000 where sheet.panel == nil { try await Task.sleep(for: .milliseconds(10)) }
        let panel = try XCTUnwrap(sheet.panel)
        sheet.set(try XCTUnwrap(panel.parts.first), to: "Show the weather here")
        XCTAssertEqual(sheet.panel?.parts.first?.value, "Show the weather here")

        sheet.press(try XCTUnwrap(panel.parts.last))

        for _ in 0..<6000 where (try? saved("clipboard"))?.contains("what the spot runs on my computer.") != true {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(try saved("clipboard").contains("Build an Openspot spot that does this: Show the weather here"))
        for _ in 0..<6000 where sheet.panel?.parts.last?.title != "✓ Copied" { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(sheet.panel?.parts.last?.title, "✓ Copied")
        XCTAssertEqual(sheet.panel?.tree.look(of: "copy"), .strong)
        XCTAssertEqual(sheet.panel?.parts.last?.press, .line)
        XCTAssertEqual(sheet.panel?.parts.first?.value, "Show the weather here")
        for _ in 0..<6000 where sheet.panel?.parts.last?.title != "Copy prompt" { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(sheet.panel?.parts.last?.title, "Copy prompt")
        XCTAssertEqual(sheet.panel?.parts.first?.value, "Show the weather here")
    }

    private func editSheet(of id: String) throws -> Spot {
        let place = SpotsFolder(url: spots, core: core, enabled: ["cups"])
        let owner = try XCTUnwrap(try place.scan().scripts.first { $0.id == id })
        return try XCTUnwrap(try newSpot().editSheet(of: owner, isOwn: !place.isCore(owner)))
    }

    private func edit(_ sheet: Spot, _ action: SpotWords, input: String? = nil, variables: [String: String] = [:]) async throws -> String {
        try await SpotRuns(environment: TestEnvironment.values).answer(of: sheet, action, input: input, limit: 60, variables: variables)
    }

    func testTheEditSheetIsTheSameFormForAChangeWithOpenInEditor() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")
        let sheet = try editSheet(of: "weather")

        let output = Frame(text: try await edit(sheet, .show))

        XCTAssertEqual(sheet.name, "Edit Weather")
        XCTAssertEqual(output.parts.map(\.id), ["describe", "copy"])
        XCTAssertEqual(output.fields.map { $0.block.value("type") }, ["multiline"])
        XCTAssertEqual(output.parts.first?.control, .text("", placeholder: "Describe what you want to change", isReadOnly: false))
        XCTAssertEqual(output.parts.last?.title, "Copy prompt")
        XCTAssertEqual(output.tree.look(of: "copy"), .strong)
        XCTAssertEqual(output.parts.last?.key, ActionKey(name: "return", isCommand: true))
        XCTAssertEqual(output.actions.map(\.title), ["Clear", "Open in editor", "Read the guide"])

        _ = try await edit(sheet, SpotWords(arguments: ["editor"]))
        XCTAssertEqual(try saved("opened"), "-t \(spots.spotFile("weather").path)\n")
    }

    func testCopyPromptOnAnEditSheetCopiesTheChangeOfTheSpotsFileToTheEnd() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")

        _ = try await edit(try editSheet(of: "weather"), .press("copy"), input: "input.describe=Add a refresh button\n")

        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasPrefix("Change the Openspot spot in \(spots.spotFile("weather").path): Add a refresh button\n\(AgentPrompt.finishChange)\n"), prompt)
        XCTAssertTrue(prompt.contains("spot run weather"))
        XCTAssertFalse(prompt.contains("comes with Openspot"))
    }

    func testCopyPromptOnAnEmptyEditSheetAsksWhatToChangeWithTheLastFailure() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")

        _ = try await edit(try editSheet(of: "weather"), .press("copy"), input: "input.describe=\n", variables: ["OPENSPOT_EDIT_FAILURE": "The server did not answer."])

        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasPrefix("Change the Openspot spot in \(spots.spotFile("weather").path). Ask me what to change before you change it."), prompt)
        XCTAssertTrue(prompt.contains("Its last call failed, and said: The server did not answer."))
        XCTAssertFalse(prompt.contains(AgentPrompt.finishChange))
    }

    func testEachSpotKeepsADraftOfItsOwnApartFromNewSpot() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("notes"), toml: "title = 'Notes'")
        let weather = try editSheet(of: "weather")
        let notes = try editSheet(of: "notes")

        _ = try await edit(weather, SpotWords(arguments: ["describe", "Add a refresh button"]), input: "input.describe=Add a refresh button\n")
        _ = try await edit(notes, SpotWords(arguments: ["describe", "Sort by date"]), input: "input.describe=Sort by date\n")

        let words = { (sheet: Spot) in Frame(text: try await self.edit(sheet, .show)).parts.first?.value ?? "" }
        let kept = (try await words(weather), try await words(notes))
        XCTAssertEqual(kept.0, "Add a refresh button")
        XCTAssertEqual(kept.1, "Sort by date")
        let new = try await newSpot().answer(.show, timeout: 60)
        XCTAssertEqual(new.parts.first?.value ?? "", "")
        _ = try await edit(weather, .press("copy"), input: "input.describe=Add a refresh button\n")
        let after = (try await words(weather), try await words(notes))
        XCTAssertEqual(after.0, "")
        XCTAssertEqual(after.1, "Sort by date")
    }

    func testACoreSpotIsCopiedIntoTheSpotsFolderFirstAndAnOwnCopyChangesInPlace() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: core.spotFile("cups"), toml: "title = 'Cups'")
        try file.turn("cups", on: true)
        let sheet = try editSheet(of: "cups")
        let copy = spots.appendingPathComponent("cups.spot", isDirectory: true)

        let read = Frame(text: try await edit(sheet, .show))
        XCTAssertFalse(read.actions.contains { $0.title == "Open in editor" })
        _ = try await edit(sheet, .press("copy"), input: "input.describe=Count in litres\n")
        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasPrefix("\(AgentPrompt(folder: spots, guide: guide, app: "").copying(core.appendingPathComponent("cups.spot"), to: copy))\n"), prompt)
        XCTAssertTrue(prompt.contains(core.appendingPathComponent("cups.spot").path))
        XCTAssertTrue(prompt.contains("Change the Openspot spot in \(copy.appendingPathComponent("cups.sh").path): Count in litres"))
        XCTAssertTrue(prompt.contains(AgentPrompt.finishChange))
        _ = try await edit(sheet, .press("copy"), input: "input.describe=\n")
        let asking = try saved("clipboard")
        XCTAssertTrue(asking.contains(core.appendingPathComponent("cups.spot").path))
        XCTAssertTrue(asking.contains("Ask me what to change"))

        try "#!/bin/sh\necho\n".writeScript(to: copy.appendingPathComponent("cups.sh"), toml: "title = 'Cups'")
        _ = try await edit(try editSheet(of: "cups"), .press("copy"), input: "input.describe=Count in litres\n")
        let own = try saved("clipboard")
        XCTAssertTrue(own.hasPrefix("Change the Openspot spot in \(copy.appendingPathComponent("cups.sh").path): Count in litres"), own)
        XCTAssertFalse(own.contains("comes with Openspot"))
    }

    func testTheActionsOpenTheGuideAndTheFolder() async throws {
        let spot = try newSpot()

        try await spot.perform(SpotWords(arguments: ["guide"]), timeout: 60)
        XCTAssertTrue(try saved("opened").contains("GUIDE.md"))

        try await spot.perform(SpotWords(arguments: ["folder"]), timeout: 60)
        XCTAssertTrue(try saved("opened").contains(spots.path))
    }

    func testAnUnknownCallFails() async throws {
        do {
            _ = try await newSpot().perform(SpotWords(arguments: ["gone"]), timeout: 60)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "New spot cannot do that.")
        }
    }

    func testTheGuideIsTheGuideThenTheProtocolWithEachLinkInThePage() throws {
        let headings = Set(guideText.split(separator: "\n").filter { $0.hasPrefix("#") && $0.contains("# ") }.map { line in
            String(line.drop { $0 == "#" }.dropFirst()).lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " || $0 == "-" }.replacingOccurrences(of: " ", with: "-")
        })
        let links = guideText.components(separatedBy: "](#").dropFirst().map { String($0.prefix { $0 != ")" }) }

        XCTAssertTrue(guideText.hasPrefix("# Openspot guide"))
        XCTAssertTrue(guideText.contains("\n# Openspot protocol\n"))
        XCTAssertFalse(guideText.contains("GUIDE.md#") || guideText.contains("PROTOCOL.md#"))
        XCTAssertGreaterThan(links.count, 20)
        for link in links {
            XCTAssertTrue(headings.contains(link), link)
        }
    }

    func testTheGuideTeachesNoOldKeyOrCall() {
        for old in ["read=open", "read=click", "live=true", "search=live", "form <action>", "search <text>", "set <id>", "press <id>", "press <word>", "openspot catalog", "while next", "openspot.input", "function read("] {
            XCTAssertFalse(guideText.contains(old), old)
        }
    }

    func testTheGuideAndThePartsTakeTheSameKeys() {
        let blocks = guideText.components(separatedBy: "## Blocks").dropFirst().first?.components(separatedBy: "\n# Layouts").first ?? ""
        for key in BlockKind.commonKeys {
            XCTAssertTrue(blocks.contains("`\(key)"), key)
        }
        for line in blocks.split(separator: "\n") where line.hasPrefix("| `") {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            let kind = cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            guard cells.count > 2, BlockKind.all.contains(where: { $0.word == kind }) else { continue }
            for item in cells[2].components(separatedBy: ", ") {
                guard let word = item.split(separator: "`", omittingEmptySubsequences: false).dropFirst().first else { continue }
                XCTAssertTrue(BlockKind.commonKeys.contains(String(word.split(separator: "=").first ?? word)), "\(kind): \(word)")
            }
        }
    }

    private func protocolGuide() throws -> String {
        let out = root.appendingPathComponent("built.md")
        let script = Process()
        script.executableURL = URL(fileURLWithPath: "/bin/sh")
        script.arguments = [repo.appendingPathComponent("scripts/guide.sh").path, out.path]
        try script.run()
        script.waitUntilExit()
        XCTAssertEqual(script.terminationStatus, 0)
        return try String(contentsOf: out, encoding: .utf8)
    }

}
