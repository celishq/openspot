import XCTest
@testable import OpenspotCore

class SampleSpotsCase: XCTestCase {
    var examples: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("examples")
    }

    var exampleScan: ScanResult {
        get throws {
            try SpotsFolder(url: examples).scan()
        }
    }

    func example(_ name: String) throws -> Spot {
        try XCTUnwrap(try exampleScan.spots.first { $0.name == name })
    }

    func built(_ name: String) async throws -> (folder: URL, program: URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-\(name)-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let program = folder.appendingPathComponent(name)
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-o", program.path, examples.appendingPathComponent("\(name).spot/\(name).swift").path], base: TestEnvironment.values)
        return (folder, program)
    }

    var scan: ScanResult {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            let folder = root.appendingPathComponent("spots")
            var scan = try SpotsFolder(url: folder).scan()
            scan.addSettings(in: ConfigFile(url: FileManager.default.temporaryDirectory.appendingPathComponent("openspot-samples/config.toml")), secrets: SecretStore(file: FileManager.default.temporaryDirectory.appendingPathComponent("openspot-samples/secrets.json")))
            return scan
        }
    }

    func windowCall(_ slot: String) throws -> String {
        let folder = try temporaryFolder()
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

    func withPrivateHome(_ more: [String: String] = [:], settings: [String: String] = [:], _ body: (URL) async throws -> Void) async throws {
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
            ("say", "exit 0")
        ] {
            let tool = tools.appendingPathComponent(name)
            try "#!/bin/sh\n\(script)\n".writeScript(to: tool)
        }
        defer { try? FileManager.default.removeItem(at: folder) }
        let home: [String: String] = [
            "HOME": folder.path,
            "TMPDIR": folder.path + "/",
            "PATH": "\(tools.path):/usr/bin:/bin",
            "APP_FOLDERS": folder.appendingPathComponent("Applications").path
        ]
        try await TestEnvironment.with(home.merging(more) { _, new in new }) {
            try await TestSettings.with(settings) { try await body(folder) }
        }
    }

    static func fakeOpenspot(in folder: URL) -> String {
        """
        case "$1 $2" in
          'clipboard copy') cat > '\(folder.path)/clipboard' ;;
          'clipboard read') cat '\(folder.path)/clipboard' 2>/dev/null ;;
          'clipboard paste') cp '\(folder.path)/clipboard' '\(folder.path)/pasted' ;;
          'setting get') cat "\(folder.path)/setting-$3" 2>/dev/null ;;
          'setting set') if [ $# -ge 4 ]; then printf '%s' "$4" > "\(folder.path)/setting-$3"; else rm -f "\(folder.path)/setting-$3"; fi ;;
          'folder pick') cat '\(folder.path)/picked' 2>/dev/null ;;
          'toast '*) shift; printf '%s\\n' "$*" >> '\(folder.path)/toasts' ;;
          'select '*) printf '%s\\n' "$2" >> '\(folder.path)/selected' ;;
          'spot open') printf '%s\\n' "$3" >> '\(folder.path)/opened-spots' ;;
        esac
        """
    }

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
          https://vector.test/)
            echo '<head><link rel="icon" href="/a.png" sizes="16x16"><link rel="icon" type="image/svg+xml" href="/b.svg" data-base-href="/b"></head>'
            ;;
          https://vector.test/a.png)
            echo 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==' | base64 -D > "$out"
            printf 'image/png'
            ;;
          https://vector.test/b.svg)
            echo '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" width="16" height="16"><circle cx="8" cy="8" r="8"/></svg>' > "$out"
            printf 'image/svg+xml'
            ;;
          *)
            exit 22
            ;;
        esac
        """
    }

    func savedLink(_ url: String, in links: Spot) async throws {
        let new = try await action("new", of: links)
        var draft = FormDraft(form: try await links.form(new, item: nil, timeout: 60))
        draft.set("Site", for: "title")
        draft.set(url, for: "url")
        _ = try await links.submit(new, item: nil, draft: draft, timeout: 60)
    }

    @MainActor
    static func answer(of spot: Spot, _ handler: String, input: String) async throws -> Frame {
        Frame(text: try await SpotRuns(environment: TestEnvironment.values).answer(of: spot, handler, input: input, limit: 30))
    }

    func action(_ id: String, of spot: Spot) async throws -> CommandAction {
        let actions = try await spot.items(timeout: 60).actions
        return try XCTUnwrap(actions.first { $0.id == id })
    }

    func toasts(in folder: URL) -> [String] {
        ((try? read("toasts", in: folder)) ?? "").split(separator: "\n").map(String.init)
    }

    func read(_ name: String, in folder: URL) throws -> String {
        try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
    }

    func pickColor(answer: String, in folder: URL) async throws {
        let script = "#!/bin/sh\n[ \"$1 $2\" = 'color pick' ] && { printf '%s' '\(answer)'; exit 0; }\n\(Self.fakeOpenspot(in: folder))\n"
        try script.writeScript(to: folder.appendingPathComponent("tools/openspot"))
        let picker = try XCTUnwrap(try scan.spots.first { $0.name == "Color picker" })
        return try await picker.perform(ScriptEntry.press.name, timeout: 60)
    }

    func fakeTranslate(in folder: URL, status: String? = nil) throws -> Spot {
        let reply = status.map { "printf 'status=\($0)\\nfrom=ru\\nto=en\\n'" } ?? #"""
        case "$text" in *[а-я]*) found=ru ;; *) found=en ;; esac
        [ "$from" = auto ] || found=$from
        written=$(printf %s "$text" | tr a-mo-z A-MO-Z | sed 's/\\/\\\\/g' | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')
        printf 'text=%s\nfrom=%s\n' "$written" "$found"
        """#
        let script = """
        #!/bin/sh
        if [ "$1" = clipboard ] || [ "$1" = toast ]; then
          \(Self.fakeOpenspot(in: folder))
          exit 0
        fi
        if [ "$2" = languages ]; then
          printf 'preferred=en\\npreferred=ru\\n\\nitem=en\\ntitle=English\\n\\nitem=ru\\ntitle=Russian\\n'
          exit 0
        fi
        from=$4
        text=$(cat; printf x)
        text=${text%x}
        \(reply)

        """
        let tool = folder.appendingPathComponent("tools/openspot")
        try script.writeScript(to: tool)
        return try XCTUnwrap(try scan.spots.first { $0.name == "Translate" })
    }

    func text(of id: String, in output: Frame) -> String? {
        output.parts.first { $0.id == id }?.value
    }

    @MainActor
    static func drive(_ spot: Spot, _ steps: [(handler: String, value: String?)]) async throws -> Frame {
        var last = try await spot.items(timeout: 60)
        var panel = try XCTUnwrap(SheetParts(output: last))
        for step in steps {
            if let value = step.value { panel.set(value, of: step.handler) }
            last = Frame(text: try await SpotRuns(environment: TestEnvironment.values).answer(of: spot, step.handler, input: Message(step.handler, inputs: panel.inputs).text, limit: 30))
            panel.take(last, answering: panel.generation)
        }
        return last
    }

    func fakeEmoji(in folder: URL) throws -> Spot {
        let script = """
        #!/bin/sh
        case "$1" in
          clipboard) \(Self.fakeOpenspot(in: folder)) ;;
          emoji) printf 'item=👍\\ntitle=thumbs up, %s\\nicon=👍\\n\\n' "$4" ;;
          symbols) printf 'item=→\\ntitle=rightwards arrow\\ndetail=Rightwards Arrows\\nicon=→\\n' ;;
        esac

        """
        try script.writeScript(to: folder.appendingPathComponent("tools/openspot"))
        try "#!/bin/sh\ncat '\(folder.path)/languages' 2>/dev/null || printf '(\\n    \"en-US\"\\n)\\n'\n".writeScript(to: folder.appendingPathComponent("tools/defaults"))
        return try XCTUnwrap(try scan.spots.first { $0.name == "Emojis & Symbols" })
    }

    @MainActor
    static func targetOptions(of spot: Spot, release: URL) async throws -> (first: Int, last: Int) {
        let runs = SpotRuns(environment: TestEnvironment.values)
        defer { runs.quit() }
        let sheet = runs.sheet(for: spot)
        let options: () -> Int = {
            guard case .menu(let options, _)? = sheet.panel?.parts.first(where: { $0.id == "target" })?.control else { return 0 }
            return options.count
        }
        runs.panelOpened()
        sheet.open {}
        for _ in 0..<6000 where sheet.panel == nil { try await Task.sleep(for: .milliseconds(10)) }
        let first = options()
        FileManager.default.createFile(atPath: release.path, contents: Data())
        for _ in 0..<6000 where options() < 2 { try await Task.sleep(for: .milliseconds(10)) }
        return (first, options())
    }
}
