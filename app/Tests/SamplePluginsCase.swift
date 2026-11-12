import XCTest
@testable import OpenspotCore

/// The scan of the repo plugins and the fakes and helpers of the tests that run them.
class SamplePluginsCase: XCTestCase {
    /// The folder of the example plugins, which the app does not ship.
    var examples: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples")
    }

    var exampleScan: ScanResult {
        get throws {
            try SpotFolder(url: examples).scan()
        }
    }

    /// The example spot with this name.
    func example(_ name: String) throws -> Spot {
        try XCTUnwrap(try exampleScan.spots.first { $0.name == name })
    }

    var scan: ScanResult {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let folder = root.appendingPathComponent("plugins")
            var scan = try SpotFolder(url: folder).scan()
            scan.listKeys(in: ConfigFile(url: FileManager.default.temporaryDirectory.appendingPathComponent("openspot-samples/config.toml")))
            return scan
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
        XCTAssertEqual(first?.run, "off")

        let stopToast = try await caffeinate.perform(.item(try XCTUnwrap(first)), timeout: 5)
        XCTAssertEqual(stopToast, "Caffeinate is off")
        let stopped = try await caffeinate.state(timeout: 5)
        XCTAssertEqual(stopped.subtitle, "Off")
    }

    /// Runs with an empty home and temp folder and with fake clipboard, open and caffeinate tools, so a test touches nothing
    /// of the person's. The fake caffeinate is a process of that name that only waits, and `pbcopy` and `pbpaste` add their
    /// names to the file `direct`.
    func withPrivateHome(_ body: (URL) async throws -> Void) async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-home-\(UUID().uuidString)")
        let tools = folder.appendingPathComponent("tools")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        for (name, script) in [
            ("pbcopy", "echo pbcopy >> '\(folder.path)/direct'; cat > '\(folder.path)/clipboard'"),
            ("pbpaste", "echo pbpaste >> '\(folder.path)/direct'; cat '\(folder.path)/clipboard' 2>/dev/null"),
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

    /// The openspot command: a sum prints the file `calc-answer` and adds its words to `calc-asked`, a copy writes the file
    /// `clipboard`, a read prints it, and a paste copies it to `pasted`. A setting is the file
    /// `setting-<key>`, and a folder pick prints the file `picked`.
    static func fakeOpenspot(in folder: URL) -> String {
        """
        case "$1 $2" in
          'calc solve') printf '%s\\n' "$3" >> '\(folder.path)/calc-asked'; cat '\(folder.path)/calc-answer' 2>/dev/null ;;
          'clipboard copy') cat > '\(folder.path)/clipboard' ;;
          'clipboard read') cat '\(folder.path)/clipboard' 2>/dev/null ;;
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
    func action(_ id: String, of spot: Spot) async throws -> CommandAction {
        let actions = try await spot.items(timeout: 5).actions
        return try XCTUnwrap(actions.first { $0.id == id })
    }

    func read(_ name: String, in folder: URL) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    /// Runs the color picker with a stand-in for the openspot command, which prints this answer and copies as the fake of
    /// `withPrivateHome` does.
    func pickColor(answer: String, in folder: URL) async throws -> String? {
        let script = "#!/bin/sh\n[ \"$1 $2\" = 'color pick' ] && { printf '%s' '\(answer)'; exit 0; }\n\(Self.fakeOpenspot(in: folder))\n"
        try script.writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let picker = try XCTUnwrap(try scan.spots.first { $0.name == "Color picker" })
        return try await picker.perform(picker.click, timeout: 5)
    }

    /// Puts a stand-in for the openspot command on the path. It knows two languages, translates to upper case, and copies as
    /// the fake of `withPrivateHome` does.
    func fakeTranslate(in folder: URL, status: String? = nil) throws -> Spot {
        let reply = status.map { "printf 'status=\($0)\\nfrom=ru\\nto=en\\n'" } ?? #"""
        case "$text" in *[а-я]*) found=ru ;; *) found=en ;; esac
        [ "$from" = auto ] || found=$from
        written=$(printf %s "$text" | tr a-mo-z A-MO-Z | sed 's/\\/\\\\/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
        printf 'text=%s\nfrom=%s\n' "$written" "$found"
        """#
        let script = """
        #!/bin/sh
        if [ "$1" = clipboard ]; then
          \(Self.fakeOpenspot(in: folder))
          exit 0
        fi
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
        return try XCTUnwrap(try scan.spots.first { $0.name == "Translate" })
    }

    func text(of id: String, in output: SpotOutput) -> String? {
        output.parts.first { $0.id == id }?.value
    }

    /// Runs a handler through the calls as an open sheet does: one run for each, with the values of the sheet on stdin.
    /// Returns the answer to the last one.
    @MainActor
    static func drive(_ spot: Spot, _ actions: [SpotAction]) async throws -> SpotOutput {
        var last = try await spot.items(timeout: 10)
        var panel = try XCTUnwrap(SheetParts(output: last))
        for action in actions {
            if action.arguments.count == 2 { panel.set(action.arguments[1], of: action.arguments[0]) }
            last = SpotOutput(text: try await SpotRuns().answer(of: spot, action, input: panel.values, limit: 30))
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
        return try XCTUnwrap(try scan.spots.first { $0.name == "Emojis & Symbols" })
    }

    /// Reads a sheet, and returns the options of its target menu with its first parts, and after `release` appears.
    @MainActor
    static func targetOptions(of spot: Spot, release: URL) async throws -> (first: Int, last: Int) {
        let runs = SpotRuns()
        defer { runs.quit() }
        let sheet = runs.sheet(for: spot)
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
