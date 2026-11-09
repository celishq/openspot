import XCTest
@testable import OpenspotCore

/// The scan of the repo plugins and the fakes and helpers of the tests that run them.
class SamplePluginsCase: XCTestCase {
    var scan: ScanResult {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let folder = root.appendingPathComponent("plugins")
            let shipped = ShippedSpot.commands(folder: folder, guide: root.appendingPathComponent("app/Shell/GUIDE.md"), app: "")
            return try PluginFolder(url: folder).scan(shipped: shipped)
        }
    }

    /// The scan of the repo examples, which the app does not ship.
    var examples: ScanResult {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            return try PluginFolder(url: root.appendingPathComponent("examples")).scan()
        }
    }

    /// The arguments that Windows passes to `openspot` for a slot, one per line.
    func windowCall(_ slot: String) throws -> String {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-windows-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        try "#!/bin/sh\nprintf '%s\\n' \"$@\"\n".writeScript(to: folder.appendingPathComponent("openspot"))
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [try XCTUnwrap(try scan.scripts.first { $0.name == "Windows" }).url.path, slot]
        process.environment = ["PATH": "\(folder.path):/usr/bin:/bin"]
        let output = Pipe()
        process.standardOutput = output
        try process.run()
        process.waitUntilExit()
        return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    func turnCaffeinateOnAndOff(_ caffeinate: Spot) async throws {
        let toast = try await caffeinate.perform(.item(SpotItem(title: "1 minute", run: "60")), timeout: 5)
        XCTAssertEqual(toast, "Caffeinate is on for 1 minute")
        var started = try await caffeinate.state(timeout: 5)
        for _ in 0..<100 where started.subtitle == "Off" {
            try await Task.sleep(for: .milliseconds(50))
            started = try await caffeinate.state(timeout: 5)
        }
        let first = try await caffeinate.items(timeout: 5).items.first
        XCTAssertEqual(started.subtitle, "1m left")
        XCTAssertEqual(started.on, true)
        XCTAssertEqual(first?.run, "off")

        let stopToast = try await caffeinate.perform(.item(try XCTUnwrap(first)), timeout: 5)
        XCTAssertEqual(stopToast, "Caffeinate is off")
        let stopped = try await caffeinate.state(timeout: 5)
        XCTAssertEqual(stopped.subtitle, "Off")
        XCTAssertEqual(stopped.on, false)
    }

    /// Runs with an empty home and temp folder and with fake clipboard, open and caffeinate tools, so a test touches nothing
    /// of the person's. The fake caffeinate is a process of that name that only waits.
    func withPrivateHome(_ body: (URL) async throws -> Void) async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-home-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        for (name, script) in [
            ("pbcopy", "cat > '\(folder.path)/clipboard'"),
            ("pbpaste", "cat '\(folder.path)/clipboard' 2>/dev/null"),
            ("open", "echo \"$1\" > '\(folder.path)/opened'"),
            ("curl", Self.fakeCurl(log: folder.appendingPathComponent("fetched").path)),
            ("gh", Self.fakeGh(answer: folder.appendingPathComponent("gh-answer").path)),
            ("osascript", "cp '\(folder.path)/clipboard' '\(folder.path)/pasted'"),
            ("openspot", Self.fakeOpenspot(in: folder)),
            ("caffeinate", "exec /bin/bash -c 'exec -a caffeinate /bin/sleep 30'")
        ] {
            let tool = tools.appendingPathComponent(name)
            try "#!/bin/sh\n\(script)\n".writeScript(to: tool)
        }
        let before = ProcessInfo.processInfo.environment
        setenv("HOME", folder.path, 1)
        setenv("TMPDIR", folder.path + "/", 1)
        setenv("PATH", "\(tools.path):/usr/bin:/bin", 1)
        setenv("APP_FOLDERS", folder.appendingPathComponent("Applications").path, 1)
        defer {
            for name in ["HOME", "TMPDIR", "PATH", "APP_FOLDERS"] {
                if let value = before[name] { setenv(name, value, 1) } else { unsetenv(name) }
            }
            try? FileManager.default.removeItem(at: folder)
        }
        try await body(folder)
    }

    /// The openspot command: a copy writes the file `clipboard`, and a paste copies it to `pasted`. A setting is the file
    /// `setting-<key>`, and a folder pick prints the file `picked`.
    static func fakeOpenspot(in folder: URL) -> String {
        """
        case "$1 $2" in
          'clipboard copy') cat > '\(folder.path)/clipboard' ;;
          'clipboard paste') cp '\(folder.path)/clipboard' '\(folder.path)/pasted' ;;
          'setting get') cat "\(folder.path)/setting-$3" 2>/dev/null ;;
          'setting set') if [ $# -ge 4 ]; then printf '%s' "$4" > "\(folder.path)/setting-$3"; else rm -f "\(folder.path)/setting-$3"; fi ;;
          'folder pick') cat '\(folder.path)/picked' 2>/dev/null ;;
        esac
        """
    }

    /// Answers a query with the saved answer, or else with one pull request in each state.
    static func fakeGh(answer: String) -> String {
        """
        [ -f '\(answer)' ] && { cat '\(answer)'; exit 0; }
        cat <<'END'
        {"data":{
          "mine":{"nodes":[
            {"title":"Fix \\\\ \\"tray\\"","url":"https://github.test/a/1","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"FAILURE"}}}]}},
            {"title":"Live mode","url":"https://github.test/a/2","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}},
            {"title":"Docs","url":"https://github.test/a/3","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}}
          ]},
          "asked":{"nodes":[
            {"title":"Live mode","url":"https://github.test/a/2","repository":{"name":"a"},"commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"PENDING"}}}]}},
            {"title":"Review me","url":"https://github.test/b/4","repository":{"name":"b"},"commits":{"nodes":[{"commit":{"statusCheckRollup":null}}]}}
          ]}
        }}
        END
        """
    }

    /// A web with one site: icons.test names a small image on its page, and each other site has no image at all.
    static func fakeCurl(log: String) -> String {
        """
        out=""
        for a; do
          [ "$previous" = "-o" ] && out=$a
          previous=$a
          url=$a
        done
        echo "$url" >> '\(log)'
        case "$url" in
          https://icons.test/)
            echo '<head><link href="/a.png" rel="icon"></head>'
            ;;
          https://icons.test/a.png)
            echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -D > "$out"
            printf 'image/png'
            ;;
          *)
            exit 22
            ;;
        esac
        """
    }

    func savedLink(_ url: String, in links: Spot) async throws {
        let new = try await action("new", of: links)
        var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 5))
        draft.set("Site", for: "title")
        draft.set(url, for: "url")
        _ = try await links.submit(new, item: nil, draft: draft, timeout: 5)
    }

    /// Reads a script to find the action that it prints.
    func action(_ id: String, of command: Spot) async throws -> CommandAction {
        let actions = try await command.items(timeout: 5).actions
        return try XCTUnwrap(actions.first { $0.id == id })
    }

    func read(_ name: String, in folder: URL) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    /// Runs the color picker with a stand-in for the openspot command, which prints this answer.
    func pickColor(answer: String, in folder: URL) async throws -> String? {
        try "#!/bin/sh\n[ \"$1 $2\" = 'color pick' ] && printf '%s' '\(answer)'\n".writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let picker = try XCTUnwrap(try scan.commands.first { $0.name == "Color picker" })
        return try await picker.perform(picker.click, timeout: 5)
    }

    /// Puts a stand-in for the openspot command on the path. It knows two languages and translates to upper case.
    func fakeTranslate(in folder: URL, status: String? = nil) throws -> Spot {
        let reply = status.map { "printf 'status=\($0)\\nfrom=ru\\nto=en\\n'" } ?? #"""
        case "$text" in *[а-я]*) found=ru ;; *) found=en ;; esac
        [ "$from" = auto ] || found=$from
        written=$(printf %s "$text" | tr a-mo-z A-MO-Z | sed 's/\\/\\\\/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
        printf 'text=%s\nfrom=%s\n' "$written" "$found"
        """#
        let script = """
        #!/bin/sh
        if [ "$2" = languages ]; then
          printf 'preferred=en\\npreferred=ru\\n\\nlanguage=en\\nname=English\\n\\nlanguage=ru\\nname=Russian\\n'
          exit 0
        fi
        from=$3
        text=$(cat; printf x)
        text=${text%x}
        \(reply)

        """
        let tool = folder.appendingPathComponent("tools/openspot")
        try script.writeScript(to: tool)
        return try XCTUnwrap(try scan.commands.first { $0.name == "Translate" })
    }

    func text(of id: String, in output: PluginOutput) -> String? {
        output.parts.first { $0.id == id }?.value
    }

    /// Runs a handler through the calls as an open sheet does: one run for each, with the values of the sheet on stdin.
    /// Returns the answer to the last one.
    @MainActor
    static func drive(_ command: Spot, _ actions: [SpotAction]) async throws -> PluginOutput {
        var last = try await command.items(timeout: 10)
        var panel = try XCTUnwrap(SheetParts(output: last))
        for action in actions {
            if action.arguments.count == 2 { panel.set(action.arguments[1], of: action.arguments[0]) }
            last = PluginOutput(text: try await SpotRuns().answer(of: command, action, input: panel.values, limit: 30))
            panel.take(last, answering: panel.generation)
        }
        return last
    }

    func fakeEmoji(in folder: URL) throws -> Spot {
        let script = """
        #!/bin/sh
        case "$1" in
          clipboard) \(Self.fakeOpenspot(in: folder)) ;;
          emoji) printf 'row=👍\\ntitle=thumbs up, %s\\nicon=👍\\n\\n' "$3" ;;
          symbols) printf 'row=→\\ntitle=rightwards arrow\\ndetail=Rightwards Arrows\\nicon=→\\n' ;;
        esac

        """
        try script.writeScript(to: folder.appendingPathComponent("tools/openspot"))
        return try XCTUnwrap(try scan.commands.first { $0.name == "Emojis & Symbols" })
    }

    /// Reads a sheet, and returns the options of its target menu with its first parts, and after `release` appears.
    @MainActor
    static func targetOptions(of command: Spot, release: URL) async throws -> (first: Int, last: Int) {
        let runs = SpotRuns()
        defer { runs.quit() }
        let sheet = runs.sheet(for: command)
        let options: () -> Int = {
            guard case .menu(let options, _)? = sheet.panel?.parts.first(where: { $0.id == "target" })?.control else { return 0 }
            return options.count
        }
        runs.panelOpened()
        sheet.open {}
        for _ in 0..<1000 where sheet.panel == nil { try await Task.sleep(for: .milliseconds(10)) }
        let first = options()
        FileManager.default.createFile(atPath: release.path, contents: Data())
        for _ in 0..<1000 where options() < 2 { try await Task.sleep(for: .milliseconds(10)) }
        return (first, options())
    }
}
