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
        try fake("claude", "exit 0")
        try fake("mdfind", "exit 0")
        _ = try await newSpot().answer("describe", timeout: 60)
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
        XCTAssertEqual(SpotChoices().spot(openedBy: ActionKey(name: "n", isCommand: true), over: defaults.arrangement), spot.id)
    }

    func testTheSheetIsOnlyAFieldToDescribeTheSpotThenTheAgentWhereItWorksCopyPromptAndMake() async throws {
        let output = try await newSpot().items(timeout: 60)

        XCTAssertEqual(output.parts.map(\.id), ["describe", "agent", "place", "make-0", "copy"])
        XCTAssertEqual(output.items, [])
        let field = try XCTUnwrap(output.parts.first)
        XCTAssertEqual(output.fields.first?.block.value("type"), "multiline")
        XCTAssertEqual(field.control, .text("", placeholder: "Describe what you want to build", isReadOnly: false))
        let copy = try XCTUnwrap(output.parts.first { $0.id == "copy" })
        XCTAssertEqual(copy.title, "Copy prompt")
        XCTAssertEqual(copy.key, ActionKey(name: "return", isCommand: true, isShift: true))
        let make = try XCTUnwrap(output.parts.first { $0.id == "make-0" })
        XCTAssertEqual(make.title, "Build")
        XCTAssertFalse(make.closes)
        XCTAssertEqual(output.tree.look(of: make.id), .strong)
        XCTAssertEqual(make.key, ActionKey(name: "return", isCommand: true))
        XCTAssertEqual(output.actions.map(\.title), ["Clear", "Read the guide", "Builds", "Open spots folder"])
    }

    func testAnAgentWhoseAppHasAnotherNameAndShipsItsCommandInsideWorksInOpenspotAndInItsApp() async throws {
        let app = try fakeApp("ChatGPT", id: "com.openai.codex")
        try "#!/bin/sh\nexit 0\n".writeScript(to: app.appendingPathComponent("Contents/Resources/codex-cli/bin/codex"))
        try fake("mdfind", "echo '\(app.path)'")
        try fake("defaults", "echo Dark")
        try forgetWays()

        let output = try await newSpot().answer("describe", input: "setting.agent=codex\n", timeout: 60)

        XCTAssertEqual(options(of: "agent", in: output.parts).map(\.title), ["Claude Code", "Codex"])
        XCTAssertEqual(options(of: "agent", in: output.parts).map { $0.icon?.image.map { URL(fileURLWithPath: $0).pathComponents.suffix(2).joined(separator: "/") } }, ["white/claude.png", "white/openai.png"])
        let places = options(of: "place", in: output.parts)
        XCTAssertEqual(places.first?.title, "Openspot")
        XCTAssertEqual(places.first { $0.id == "app-codex" }?.title, "ChatGPT", "\(places)")
        XCTAssertEqual(places.first { $0.id == "app-codex" }?.icon, .file(app.path))
    }

    func testAnEditorWithClaudeCodeIsAnAppThatTheNextOpenFindsWhileTheSheetShowsTheKeptList() async throws {
        let home = root.appendingPathComponent("home")
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".vscode/extensions/anthropic.claude-code-2.1.0"), withIntermediateDirectories: true)
        let app = try fakeApp("Visual Studio Code", id: "com.microsoft.VSCode")
        try fake("mdfind", "echo '\(app.path)'")

        try await TestEnvironment.with(["HOME": home.path]) {
            let runs = SpotRuns(environment: TestEnvironment.values)
            defer { runs.quit() }
            runs.panelOpened()
            let sheet = runs.sheet(for: try newSpot())
            sheet.open {}
            let places = { self.options(of: "place", in: sheet.panel?.parts ?? []).map(\.title) }

            try await wait("the kept list") { !places().isEmpty }
            XCTAssertFalse(places().contains("VS Code"))
            try await wait("VS Code among the apps") { places().last == "VS Code" }
            XCTAssertEqual(sheet.panel?.parts.first { $0.id == "place" }?.title, "App")
        }
    }

    func testBuildInTheClaudeAppOpensANewSessionWithThePromptAndNoFolderAndLeavesTheClipboard() async throws {
        let app = try fakeApp("Claude", id: "com.anthropic.claudefordesktop")
        try fake("mdfind", "echo '\(app.path)'")
        let real = tools.appendingPathComponent("openspot-real")
        try fake("openspot", """
        case "$1 $2" in
          'clipboard '*) echo "$@" >> '\(root.path)/clipboard' ;;
          *) exec '\(real.path)' "$@" ;;
        esac
        """)
        try forgetWays()
        let places = options(of: "place", in: try await newSpot().answer("describe", timeout: 60).parts).map(\.id)
        XCTAssertEqual(Array(places.prefix(2)), ["openspot", "app-claude"])
        let rest = places.dropFirst(2)
        XCTAssertFalse(zip(rest, rest.dropFirst()).contains { !$0.hasPrefix("term-") && $1.hasPrefix("term-") }, "\(places)")

        let output = try await newSpot().answer("make-0", input: "input.describe=A timer\nsetting.place=app-claude\n", timeout: 60)

        XCTAssertTrue(output.errors.isEmpty, "\(output.errors)")
        let opened = try XCTUnwrap(URLComponents(string: try saved("opened").trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(opened.scheme, "claude")
        XCTAssertEqual(opened.path, "/new")
        XCTAssertNil(opened.queryItems?.first { $0.name == "folder" })
        XCTAssertEqual(opened.queryItems?.first { $0.name == "q" }?.value?.contains("<request>\nA timer\n</request>"), true, "\(opened)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("clipboard").path))
    }

    func testBuildInAnAppHidesThePanelAndBuildInOpenspotKeepsIt() async throws {
        let app = try fakeApp("Claude", id: "com.anthropic.claudefordesktop")
        try fake("mdfind", "echo '\(app.path)'")
        try forgetWays()
        let build = { (place: String) in try await self.newSpot().answer("describe", input: "setting.place=\(place)\n", timeout: 60).parts.first { $0.id.hasPrefix("make-") } }

        let inApp = try await build("app-claude")
        let here = try await build("openspot")

        XCTAssertEqual(inApp?.closes, true)
        XCTAssertEqual(here?.closes, false)
    }

    func testBuildInChatGPTOpensANewCodexThreadWithThePromptAndNoFolder() async throws {
        let app = try fakeApp("ChatGPT", id: "com.openai.codex")
        try "#!/bin/sh\nexit 0\n".writeScript(to: app.appendingPathComponent("Contents/Resources/codex-cli/bin/codex"))
        try fake("mdfind", "echo '\(app.path)'")
        try forgetWays()

        let output = try await newSpot().answer("make-0", input: "input.describe=A timer\nsetting.agent=codex\nsetting.place=app-codex\n", timeout: 60)

        XCTAssertTrue(output.errors.isEmpty, "\(output.errors)")
        let opened = try XCTUnwrap(URLComponents(string: try saved("opened").trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(opened.scheme, "codex")
        XCTAssertEqual(opened.host, "new")
        XCTAssertNil(opened.queryItems?.first { $0.name == "path" })
        XCTAssertEqual(opened.queryItems?.first { $0.name == "prompt" }?.value?.contains("<request>\nA timer\n</request>"), true, "\(opened)")
    }

    func testABuildInOpenspotNamesTheFolderOfItsSpotBeforeTheAgentStarts() async throws {
        try fake("claude", "cat > '\(root.path)/asked'")
        try forgetWays()

        _ = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\nsetting.agent=claude\nsetting.place=openspot\n", timeout: 60)

        let asked = try saved("asked")
        XCTAssertTrue(asked.contains("Build the spot in the folder \(spots.path)/log-run-distance.spot."), asked)
    }

    func testABuildInOpenspotStartsItsSpotAsADraft() async throws {
        try fake("claude", "cat \"$PWD/log-run-distance.spot/spot.toml\" > '\(root.path)/seen'")
        try forgetWays()

        _ = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\nsetting.agent=claude\nsetting.place=openspot\n", timeout: 60)

        let seen = try saved("seen")
        XCTAssertTrue(seen.contains("state = \"draft\""), seen)
    }

    func testADoneBuildTakesTheDraftOffItsSpotAndPushesItToTheTopOfTheGrid() async throws {
        try fake("claude", """
        printf '#!/bin/sh\\necho hi\\n' > "$PWD/log-run-distance.spot/log-run-distance.sh"
        chmod +x "$PWD/log-run-distance.spot/log-run-distance.sh"
        echo Done
        """)
        let real = tools.appendingPathComponent("openspot-real")
        try fake("openspot", """
        echo "$@" >> '\(root.path)/calls'
        case "$1 $2" in
          'grid top' | 'toast '*) exit 0 ;;
        esac
        exec '\(real.path)' "$@"
        """)
        try forgetWays()

        _ = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\nsetting.agent=claude\nsetting.place=openspot\n", timeout: 60)

        let toml = try String(contentsOf: spots.appendingPathComponent("log-run-distance.spot/spot.toml"), encoding: .utf8)
        XCTAssertFalse(toml.contains("state"), toml)
        let calls = try saved("calls")
        XCTAssertTrue(calls.contains("grid top log-run-distance"), calls)
        XCTAssertTrue(calls.contains("toast --id build-"), calls)
        XCTAssertTrue(calls.contains("toast --remove build-"), calls)
    }

    func testBuildingAgainFromAFailedNewBuildNamesTheSameFolder() async throws {
        try fake("claude", "cat > '\(root.path)/asked'")
        try forgetWays()
        let settings = "setting.agent=claude\nsetting.place=openspot\n"
        _ = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\n" + settings, timeout: 60)
        let paths = FileManager.default.enumerator(atPath: root.path)?.allObjects as? [String] ?? []
        let builds = root.appendingPathComponent(try XCTUnwrap(paths.first { $0.hasSuffix("/builds") }))
        let job = try XCTUnwrap(try FileManager.default.contentsOfDirectory(atPath: builds.path).first)

        _ = try? await newSpot().answer("make-0", input: "input.route=build/\(job)\ninput.describe=Try again\n" + settings, timeout: 60)

        let asked = try saved("asked")
        XCTAssertTrue(asked.contains("<request>\nTry again\n</request>"), asked)
        XCTAssertTrue(asked.contains("Build the spot in the folder \(spots.path)/log-run-distance.spot."), asked)
    }

    func testTheFolderOfANewSpotIsNamedByTheLatinWordsOfItsNameOrElseSpot() async throws {
        try fake("claude", "cat > '\(root.path)/asked'")
        try forgetWays()
        let settings = "setting.agent=claude\nsetting.place=openspot\n"

        _ = try? await newSpot().answer("make-0", input: "input.describe=Кава timer\n" + settings, timeout: 60)
        let mixed = try saved("asked")
        _ = try? await newSpot().answer("make-0", input: "input.describe=Кава тиждень\n" + settings, timeout: 60)
        let cyrillic = try saved("asked")

        XCTAssertTrue(mixed.contains("Build the spot in the folder \(spots.path)/timer.spot."), mixed)
        XCTAssertTrue(cyrillic.contains("Build the spot in the folder \(spots.path)/spot.spot."), cyrillic)
    }

    func testABuildInOpenspotTellsTheAgentHowToReportEachStep() async throws {
        try fake("claude", "cat > '\(root.path)/asked'")
        try forgetWays()

        _ = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\nsetting.agent=claude\nsetting.place=openspot\n", timeout: 60)

        let asked = try saved("asked")
        XCTAssertTrue(asked.contains("spot run openspot/new step build=b"), asked)
    }

    func testAStepThatTheAgentReportsBecomesTheStepOfItsBuild() async throws {
        _ = try await newSpot().answer("step", input: "input.build=b1\ninput.words=Writing view.html\n", timeout: 60)

        let paths = FileManager.default.enumerator(atPath: root.path)?.allObjects as? [String] ?? []
        let step = try XCTUnwrap(paths.first { $0.hasSuffix("builds/b1/step") })
        XCTAssertEqual(try saved(step), "Writing view.html")
    }

    func testAFailedAgentShowsItsLastLine() async throws {
        try fake("claude", "echo 'Starting'\necho 'Not signed in. Run claude auth login.' >&2\nexit 1")
        try forgetWays()

        let failed = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\nsetting.agent=claude\nsetting.place=openspot\n", timeout: 60)

        XCTAssertNil(failed)
        let paths = FileManager.default.enumerator(atPath: root.path)?.allObjects as? [String] ?? []
        let said = try XCTUnwrap(paths.first { $0.hasSuffix("/said") })
        XCTAssertEqual(try saved(said), "Not signed in. Run claude auth login.")
    }

    func testABuildWithCodexGivesItThePromptOnStdinAndASandboxThatReachesOpenspot() async throws {
        try fake("codex", "echo \"$@\" > '\(root.path)/args'\ncat > '\(root.path)/asked'")
        try forgetWays()

        _ = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\nsetting.agent=codex\nsetting.place=openspot\n", timeout: 60)

        let args = try saved("args")
        XCTAssertTrue(args.hasPrefix("exec --skip-git-repo-check -s workspace-write -c sandbox_workspace_write.network_access=true"), args)
        XCTAssertTrue(try saved("asked").contains("<request>\nLog my run distance\n</request>"))
    }

    func testAnAliasOfTheShellThatRunsClaudeIsAnAgentOfItsOwn() async throws {
        let alias = "alias claude-personal='OPENSPOT_ACCOUNT=personal claude'\n"
        for rc in [".zshrc", ".bashrc"] { try alias.write(to: root.appendingPathComponent("home/\(rc)"), atomically: true, encoding: .utf8) }
        try fake("claude", "echo \"$OPENSPOT_ACCOUNT\" > '\(root.path)/account'")
        try forgetWays()

        let output = try await newSpot().answer("describe", timeout: 60)
        _ = try? await newSpot().answer("make-0", input: "input.describe=Log my run distance\nsetting.agent=claude-personal\nsetting.place=openspot\n", timeout: 60)

        XCTAssertTrue(options(of: "agent", in: output.parts).map(\.id).contains("claude-personal"), "\(options(of: "agent", in: output.parts))")
        XCTAssertEqual(try saved("account"), "personal\n")
    }

    private func fakeApp(_ name: String, id: String) throws -> URL {
        let app = root.appendingPathComponent("\(name).app")
        try FileManager.default.createDirectory(at: app.appendingPathComponent("Contents"), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": id], format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        return app
    }

    private func forgetWays() throws {
        let paths = FileManager.default.enumerator(atPath: root.path)?.allObjects as? [String] ?? []
        for path in paths where path.hasSuffix("/ways") { try FileManager.default.removeItem(at: root.appendingPathComponent(path)) }
    }

    private func options(of id: String, in parts: [SpotPart]) -> [SpotPart.Option] {
        guard case .menu(let options, _) = parts.first(where: { $0.id == id })?.control else { return [] }
        return options
    }

    func testTheFieldKeepsTheWordsThatThePersonTypesAcrossAReadAndACall() async throws {
        let spot = try newSpot()

        for action in ["show", "describe"] {
            let output = try await spot.answer(action, input: "input.describe=Show the weather\\nin Kyiv\n", timeout: 60)
            XCTAssertEqual(output.parts.first?.value, "Show the weather\nin Kyiv", action)
        }
    }

    func testEverySearchEndsWithARowThatMakesASpotOfTheTypedWords() async throws {
        let make = try newSpot()

        let rows = try await make.answer("search", input: "input.text= time in kyiv \n", timeout: 60).answers(asCard: false)

        XCTAssertEqual(try XCTUnwrap(make.triggers.search).isLast, true)
        XCTAssertEqual(rows.map(\.run), ["time in kyiv"])
        XCTAssertEqual(rows.map(\.title), ["Make a spot"])
        XCTAssertEqual(rows.map(\.subtitle), ["time in kyiv"])
    }

    func testAPickOfMakeASpotCopiesThePromptThatBuildsTheTypedWords() async throws {
        try await newSpot().perform("press", input: "input.item=time in kyiv\n", timeout: 60)

        XCTAssertEqual(effects(), ["toast \(SpotPrompt.copied)"])
        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasSuffix("<request>\ntime in kyiv\n</request>"), prompt)
    }

    func testAfterACopyTheNextOpenStartsEmpty() async throws {
        let spot = try newSpot()

        try await spot.perform("copy", input: "input.describe=Show the weather\n", timeout: 60)

        XCTAssertEqual(effects(), ["toast \(SpotPrompt.copied)"])
        let reopened = try await spot.answer(ScriptEntry.show.name, timeout: 60)
        XCTAssertEqual(reopened.parts.first?.value ?? "", "")
    }

    func testTheWordsStayAsADraftWhenTheSheetClosesAndClearEmptiesThem() async throws {
        let spot = try newSpot()
        _ = try await spot.answer("describe", input: "input.describe=A list of my repos\n", timeout: 60)

        let reopened = try await spot.answer(ScriptEntry.show.name, timeout: 60)
        XCTAssertEqual(reopened.parts.first?.value, "A list of my repos")

        let cleared = try await spot.answer("clear", input: "input.describe=A list of my repos\n", timeout: 60)
        XCTAssertEqual(cleared.parts.first?.value ?? "", "")
        let again = try await spot.answer(ScriptEntry.show.name, timeout: 60)
        XCTAssertEqual(again.parts.first?.value ?? "", "")
        XCTAssertEqual(again.actions.map(\.title), ["Clear", "Read the guide", "Builds", "Open spots folder"])
    }

    func testCopyPromptWithWordsCopiesThePromptThatBuildsTheSpotToTheEnd() async throws {
        let spot = try newSpot()

        try await spot.perform("copy", input: "input.describe=Show the weather\\nin Kyiv\n", timeout: 60)

        XCTAssertEqual(effects(), ["toast \(SpotPrompt.copied)"])
        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.hasSuffix("<request>\nShow the weather\nin Kyiv\n</request>"), prompt)
        XCTAssertTrue(prompt.contains(SpotPrompt.finishNew), prompt)
        XCTAssertTrue(prompt.contains(spots.path))
        XCTAssertEqual(try SpotsFolder(url: spots).scan().spots, [])
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("opened").path))
    }

    func testCopyPromptWithAnEmptyFieldAsksForTheWordsAndCopiesNothing() async throws {
        do {
            try await newSpot().perform("copy", input: "input.describe=  \n", timeout: 60)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, SpotPrompt.wordsNeeded)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("clipboard").path))
    }

    func testTheWordsOfTheFieldReachThePressAndTheButtonSaysCopiedThenCopyPromptAgain() async throws {
        let runs = SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers)
        defer { runs.quit() }
        runs.panelOpened()
        let sheet = runs.sheet(for: try newSpot())
        sheet.open {}
        for _ in 0..<6000 where sheet.panel == nil { try await Task.sleep(for: .milliseconds(10)) }
        let panel = try XCTUnwrap(sheet.panel)
        sheet.set(try XCTUnwrap(panel.parts.first), to: "Show the weather here")
        XCTAssertEqual(sheet.panel?.parts.first?.value, "Show the weather here")

        sheet.press(try XCTUnwrap(panel.parts.first { $0.id == "copy" }))

        for _ in 0..<6000 where (try? saved("clipboard"))?.hasSuffix("</request>") != true {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertTrue(try saved("clipboard").hasSuffix("<request>\nShow the weather here\n</request>"))
        let copy = { sheet.panel?.parts.first { $0.id == "copy" } }
        for _ in 0..<6000 where copy()?.title != "✓ Copied" { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(copy()?.title, "✓ Copied")
        XCTAssertEqual(copy()?.press, .line)
        XCTAssertEqual(sheet.panel?.parts.first?.value, "Show the weather here")
        for _ in 0..<6000 where copy()?.title != "Copy prompt" { try await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(copy()?.title, "Copy prompt")
        XCTAssertEqual(sheet.panel?.parts.first?.value, "Show the weather here")
    }

    private func editSheet(of id: String) throws -> Spot {
        let place = SpotsFolder(url: spots, core: core)
        let owner = try XCTUnwrap(try place.scan().scripts.first { $0.id == id })
        return try XCTUnwrap(try newSpot().editSheet(of: owner, isOwn: !place.isCore(owner)))
    }

    private func edit(_ sheet: Spot, _ action: String, input: String? = nil, variables: [String: String] = [:]) async throws -> String {
        try await SpotRuns(environment: TestEnvironment.values, callers: TestEnvironment.callers).answer(of: sheet, action, input: input, limit: 60, variables: variables)
    }

    func testTheEditSheetIsTheSameFormForAChangeWithOpenInEditor() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")
        let sheet = try editSheet(of: "weather")

        let output = Frame(text: try await edit(sheet, ScriptEntry.show.name))

        XCTAssertEqual(sheet.name, "Edit Weather")
        XCTAssertEqual(output.parts.prefix(3).map(\.id), ["describe", "agent", "place"])
        XCTAssertEqual(output.fields.first?.block.value("type"), "multiline")
        XCTAssertEqual(output.parts.first?.control, .text("", placeholder: "Describe a change to weather", isReadOnly: false))
        XCTAssertEqual(output.parts.first { $0.id == "copy" }?.title, "Copy prompt")
        let change = try XCTUnwrap(output.parts.first { $0.id.hasPrefix("change-") })
        XCTAssertEqual(change.title, "Build")
        XCTAssertEqual(output.tree.look(of: change.id), .strong)
        XCTAssertEqual(change.key, ActionKey(name: "return", isCommand: true))
        XCTAssertEqual(output.actions.map(\.title), ["Clear", "Open in editor", "Read the guide"])

        _ = try await edit(sheet, "editor")
        XCTAssertEqual(try saved("opened"), "-t \(spots.spotFile("weather").path)\n")
    }

    func testCopyPromptOnAnEditSheetCopiesTheChangeOfTheSpotsFileToTheEnd() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")

        _ = try await edit(try editSheet(of: "weather"), "copy", input: "input.describe=Add a refresh button\n")

        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.contains(spots.spotFile("weather").path), prompt)
        XCTAssertTrue(prompt.contains(SpotPrompt.finishChange), prompt)
        XCTAssertTrue(prompt.hasSuffix("<request>\nAdd a refresh button\n</request>"), prompt)
        XCTAssertFalse(prompt.contains("comes with Openspot"))
    }

    func testCopyPromptOnAnEmptyEditSheetAsksForAReviewWithTheLastFailure() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")

        _ = try await edit(try editSheet(of: "weather"), "copy", input: "input.describe=\n", variables: ["OPENSPOT_EDIT_FAILURE": "The server did not answer."])

        let prompt = try saved("clipboard")
        XCTAssertTrue(prompt.contains("The server did not answer."), prompt)
        XCTAssertTrue(prompt.hasSuffix("<request>\n\(SpotPrompt.review)\n</request>"), prompt)
    }

    func testEachSpotKeepsADraftOfItsOwnApartFromNewSpot() async throws {
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("weather"), toml: "title = 'Weather'")
        try "#!/bin/sh\necho\n".writeScript(to: spots.spotFile("notes"), toml: "title = 'Notes'")
        let weather = try editSheet(of: "weather")
        let notes = try editSheet(of: "notes")

        _ = try await edit(weather, "describe", input: "input.describe=Add a refresh button\n")
        _ = try await edit(notes, "describe", input: "input.describe=Sort by date\n")

        let words = { (sheet: Spot) in Frame(text: try await self.edit(sheet, ScriptEntry.show.name)).parts.first?.value ?? "" }
        let kept = (try await words(weather), try await words(notes))
        XCTAssertEqual(kept.0, "Add a refresh button")
        XCTAssertEqual(kept.1, "Sort by date")
        let new = try await newSpot().answer(ScriptEntry.show.name, timeout: 60)
        XCTAssertEqual(new.parts.first?.value ?? "", "")
        _ = try await edit(weather, "copy", input: "input.describe=Add a refresh button\n")
        let after = (try await words(weather), try await words(notes))
        XCTAssertEqual(after.0, "")
        XCTAssertEqual(after.1, "Sort by date")
    }

    func testTheActionsOpenTheGuideAndTheFolder() async throws {
        let spot = try newSpot()

        try await spot.perform("guide", timeout: 60)
        XCTAssertTrue(try saved("opened").contains("DOCS.md"))

        try await spot.perform("folder", timeout: 60)
        XCTAssertTrue(try saved("opened").contains(spots.path))
    }

    func testAnUnknownCallFails() async throws {
        do {
            _ = try await newSpot().perform("gone", timeout: 60)
            XCTFail("expected a fault")
        } catch {
            XCTAssertEqual((error as? SpotError)?.reason, "New spot cannot do that.")
        }
    }

    func testTheGuideIsTheMapThenEachPageWithNoLinkToARepoFile() throws {
        XCTAssertTrue(guideText.hasPrefix("# How Openspot works"))
        XCTAssertTrue(guideText.contains("\n# Your first spot\n"))
        XCTAssertTrue(guideText.contains("\n# The openspot command\n"))
        XCTAssertFalse(guideText.contains("PROTOCOL.md") || guideText.contains("](docs/"))
    }

    func testEachTopicOfTheGuideIsAPageOfTheMapOnce() throws {
        let docs = try [RepoDoc("PROTOCOL.md")] + RepoDoc.pages() + [RepoDoc("MANUAL.md")]
        let topics = Guide(text: guideText, pages: [:]).topics

        XCTAssertEqual(topics.map(\.title), try docs.map { try XCTUnwrap($0.headings.first) })
        XCTAssertEqual(Set(topics.map(\.slug)).count, topics.count)
        XCTAssertEqual(topics.first { $0.title == "Your first spot" }?.text.hasPrefix("# Your first spot\n"), true)
        XCTAssertEqual(topics.first { $0.title == "Your first spot" }?.text.contains("\n## How it works\n"), true)
    }

    func testTheGuideTeachesNoOldKeyOrCall() {
        for old in ["read=open", "read=click", "live=true", "search=live", "form <action>", "search <text>", "set <id>", "press <id>", "press <word>", "openspot catalog", "while next", "openspot.input", "function read("] {
            XCTAssertFalse(guideText.contains(old), old)
        }
    }

    func testTheGuideAndThePartsTakeTheSameKeys() {
        let blocks = guideText.components(separatedBy: "## Kinds of block").dropFirst().first?.components(separatedBy: "\n## Items").first ?? ""
        for key in BlockKind.commonKeys {
            XCTAssertTrue(blocks.contains("`\(key)"), key)
        }
        for line in blocks.split(separator: "\n") where line.hasPrefix("| `") {
            let cells = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
            let kind = cells[0].trimmingCharacters(in: CharacterSet(charactersIn: "`"))
            guard cells.count > 2, let known = BlockKind.all.first(where: { $0.word == kind }) else { continue }
            for item in cells[2].components(separatedBy: "; ") {
                guard let word = item.split(separator: "`", omittingEmptySubsequences: false).dropFirst().first else { continue }
                XCTAssertTrue(BlockKind.commonKeys.union(known.keys).contains(String(word.split(separator: "=").first ?? word)), "\(kind): \(word)")
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
