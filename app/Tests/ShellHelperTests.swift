import XCTest
@testable import OpenspotCore

/// Proves `OPENSPOT_SH` with real shells and real processes.
final class ShellHelperTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func script(_ body: String, shell: String = "/bin/sh", header: String = "") throws -> URL {
        let url = folder.appendingPathComponent(UUID().uuidString)
        try "#!\(shell)\n\(header). \"$OPENSPOT_SH\"\n\(body)\n".writeScript(to: url)
        return url
    }

    private static let hard = [
        "\\", "\\\\", "a\\", "\\n", "a\\nb", "one\ntwo", "one\n", "\none", "\n", "a\\\nb", "=", "a=b=c", "-", "-n", "-e x", "--",
        "%s %d", "*", "$HOME `date`", " spaces ", "\ttab", "\"quotes\" 'too'", "héllo привет", "~", "a\n\n\\\\\n\nb"
    ]

    func testValuePrintsTheRealTextOfEachHardValueInEachShell() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\na=$(value a; printf x)\nb=$(value b; printf x)\nprintf '%s|%s' \"${a%x}\" \"${b%x}\"", shell: shell)
            for text in Self.hard {
                let input = TextBlock(fields: [.init(key: "first", value: "not this"), .init(key: "a", value: text), .init(key: "b", value: "second=\(text)")]).text

                let output = try await ScriptProcess.output(url: url, input: input, limit: 10)

                XCTAssertEqual(output, "\(text)|second=\(text)", "\(shell) \(text.debugDescription)")
            }
        }
    }

    func testEscIsTheInverseOfValueInEachShell() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\na=$(value a; printf x)\nprintf 'a=%s\\n' \"$(esc \"${a%x}\")\"", shell: shell)
            for text in Self.hard {
                let line = TextBlock(fields: [.init(key: "a", value: text)]).text

                let output = try await ScriptProcess.output(url: url, input: line, limit: 10)

                XCTAssertEqual(output, line, "\(shell) \(text.debugDescription)")
            }
        }
    }

    func testEscLeavesTheStateOfTheScriptAlone() async throws {
        let url = try script("""
        set -- one two
        IFS=:
        esc 'a\\b
        c'
        printf '|%s|%s|%s' "$IFS" "$1" "$#"
        """)

        let output = try await ScriptProcess.output(url: url, limit: 10)

        XCTAssertTrue(output.hasPrefix("a\\\\b\\nc|:|one|2"), output)
    }

    func testValueOfARepeatedKeyPrintsEachValueOnItsOwnLineInEachShellAndSize() async throws {
        let padding = String(repeating: "x", count: 2_000)
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\nvalue a", shell: shell)
            for tail in ["", padding] {
                let values = ["one two", "a\\b\nc", "three" + tail]
                let input = TextBlock(fields: values.flatMap { [.init(key: "a", value: $0), .init(key: "b", value: "not this")] }).text

                let output = try await ScriptProcess.output(url: url, input: input, limit: 10)

                XCTAssertEqual(output, values.joined(separator: "\n"), "\(shell) \(tail.count)")
            }
        }
    }

    func testValueOfAnUnknownIdPrintsNothing() async throws {
        let url = try script("value none\nvalue a=\nprintf '%s' \"$(value ''; value a)\"")

        let output = try await ScriptProcess.output(url: url, input: "a=1\n", limit: 10)

        XCTAssertEqual(output, "1")
    }

    func testValueIsSafeWithAStrictScript() async throws {
        let url = try script("set -eu\nvalue none\nvalue a\nesc x")

        let output = try await ScriptProcess.output(url: url, limit: 10)

        XCTAssertEqual(output, "x")
    }

    func testAScriptReadsATwoMegabyteValueWithValue() async throws {
        let big = String(repeating: "line \\ one=two\n", count: 2_000_000 / 15)
        let url = try script("value big")

        let output = try await ScriptProcess.output(url: url, input: TextBlock(fields: [.init(key: "big", value: big)]).text, limit: 30)

        XCTAssertEqual(output, big)
    }

    func testBothFunctionsAnswerTheSameWhenAValueIsLarge() async throws {
        let padding = String(repeating: "x", count: 5_000)
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\na=$(value a; printf x)\nprintf 'a=%s\\n' \"$(esc \"${a%x}\")\"\nprintf '%s' \"${a%x}\"", shell: shell)
            for text in Self.hard {
                let big = text + padding + text
                let line = TextBlock(fields: [.init(key: "first", value: "not this"), .init(key: "a", value: big)]).text

                let output = try await ScriptProcess.output(url: url, input: line, limit: 10)

                XCTAssertEqual(output, TextBlock(fields: [.init(key: "a", value: big)]).text + big, "\(shell) \(text.debugDescription)")
            }
        }
    }

    private static let megabyte = 1_000_000

    /// Each form of text that once made a shell loop slow.
    private static let megabyteTexts = [
        String(repeating: "a", count: megabyte),
        String(repeating: "\\", count: megabyte),
        String(repeating: "one line\n", count: megabyte / 9),
        String(repeating: String(repeating: "a", count: 99) + "\\", count: megabyte / 100)
    ]

    /// The shortest time of up to three runs, because other work on this Mac can slow one run.
    private func seconds(of url: URL, input: URL, output: URL) throws -> TimeInterval {
        var best = TimeInterval.infinity
        for _ in 0..<3 where best >= 10 {
            best = min(best, try oneRun(of: url, input: input, output: output))
        }
        return best
    }

    /// Runs a script with a file on stdin and a file on stdout, so that only the script counts, and returns its seconds.
    private func oneRun(of url: URL, input: URL, output: URL) throws -> TimeInterval {
        FileManager.default.createFile(atPath: output.path, contents: nil)
        let process = Process()
        process.executableURL = url
        process.environment = ProcessInfo.processInfo.environment
        process.standardInput = try FileHandle(forReadingFrom: input)
        process.standardOutput = try FileHandle(forWritingTo: output)
        let ended = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in ended.signal() }
        let start = Date()
        try process.run()
        ended.wait()
        return Date().timeIntervalSince(start)
    }

    func testValueFinishesAMegabyteInUnderTenSeconds() throws {
        let input = folder.appendingPathComponent("input")
        let output = folder.appendingPathComponent("output")
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("value big", shell: shell)
            for text in Self.megabyteTexts {
                let written = text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\n", with: "\\n")
                try "big=\(written)\n".write(to: input, atomically: true, encoding: .utf8)

                XCTAssertLessThan(try seconds(of: url, input: input, output: output), 10, shell)
                XCTAssertEqual(try String(contentsOf: output, encoding: .utf8) == text, true, shell)
            }
        }
    }

    func testEscFinishesAMegabyteInUnderTenSeconds() throws {
        let input = folder.appendingPathComponent("input")
        let output = folder.appendingPathComponent("output")
        try "".write(to: input, atomically: true, encoding: .utf8)
        let file = folder.appendingPathComponent("text")
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("big=$(/bin/cat '\(file.path)')\nesc \"$big\"", shell: shell)
            for text in Self.megabyteTexts {
                try text.write(to: file, atomically: true, encoding: .utf8)

                XCTAssertLessThan(try seconds(of: url, input: input, output: output), 10, shell)
                let kept = text.hasSuffix("\n") ? String(text.dropLast()) : text
                XCTAssertEqual(try TextBlock.blocks(in: "a=\(String(contentsOf: output, encoding: .utf8))\n").first?.fields.first?.value == kept, true, shell)
            }
        }
    }

    /// The body of a spot that prints the three parts of its call: its arguments, a variable, a value of stdin and all of
    /// stdin.
    private static let shownCall = """
    main() {
      printf 'text=t\\ntitle=%s\\n' "$(esc "$#|$1|$2|${OPENSPOT_REASON-}|$(value note)|$(cat)")"
    }
    openspot_serve main "$@"
    """

    /// The frames of a staying script that hold a block, which are what the app draws.
    private static func pictures(_ frames: [String]) -> [[TextBlock]] {
        frames.map { TextBlock.blocks(in: $0) }.filter { blocks in blocks.contains { !["call", "end"].contains($0.fields.first?.key ?? "") } }
    }

    func testOneMainRunsUnchangedOnceAndStaying() async throws {
        let action = SpotAction(arguments: ["read", "a b"])
        let input = "note=x\\ny\n"
        let variables = ["OPENSPOT_REASON": "panel"]
        let once = try script(Self.shownCall)
        let stays = try script(Self.shownCall, header: "# mode=stay\n")

        var onceText = ""
        for try await frame in ScriptProcess(url: once, arguments: action.arguments, mode: .once(input: input), limit: 10, variables: variables).start() {
            onceText += frame
        }
        let live = ScriptProcess(url: stays, mode: .stays, limit: 10)
        var frames = live.start().makeAsyncIterator()
        live.send(action, input: input, variables: variables, id: 1)
        var stayFrames: [String] = []
        while let frame = try await frames.next() {
            stayFrames.append(frame)
            if TextBlock.blocks(in: frame).first?.value("end") == "1" { break }
        }
        live.end()

        XCTAssertEqual(TextBlock.blocks(in: onceText).first?.value("title"), "2|read|a b|panel|x\ny|note=x\\ny")
        XCTAssertEqual(Self.pictures(stayFrames), [TextBlock.blocks(in: onceText)])
        XCTAssertEqual(TextBlock.blocks(in: stayFrames.first ?? "").first?.value("call"), "1")
    }

    func testServeGivesEachCallOnlyItsOwnVariablesAndSkipsAStop() async throws {
        let url = try script("""
        main() { printf 'got=%s|%s|%s\\n' "$1" "${OPENSPOT_VALUE-none}" "$(value a)"; }
        openspot_serve main "$@"
        printf 'over=1\\n'
        """, header: "# mode=stay\n")
        let live = ScriptProcess(url: url, mode: .stays, limit: 5)
        var frames = live.start().makeAsyncIterator()

        live.send(.read, input: "a=held\n", variables: ReadReason(event: "music.track", value: "Song").variables, id: 1)
        live.send(text: SpotAction.stopEvent(id: 1))
        live.send(.press("go"), id: 2)
        live.end()
        var printed: [String] = []
        while let frame = try await frames.next() { printed.append(frame) }

        XCTAssertEqual(printed.filter { $0.hasPrefix("got=") || $0.hasPrefix("over=") }, ["got=read|Song|held\n\n", "got=go|none|\n\n", "over=1\n"])
        XCTAssertEqual(printed.filter { $0.hasPrefix("end=") }, ["end=1\n", "end=2\n"])
    }

    func testServeKeepsAnEmptyFirstArgument() async throws {
        let url = try script("main() { printf 'count=%s|%s\\n' \"$#\" \"$2\"; }\nopenspot_serve main \"$@\"", header: "# mode=stay\n")
        let live = ScriptProcess(url: url, mode: .stays, limit: 5)
        var frames = live.start().makeAsyncIterator()

        live.send(SpotAction(arguments: ["", "x"]), id: 1)
        live.end()
        var printed: [String] = []
        while let frame = try await frames.next() { printed.append(frame) }

        XCTAssertEqual(printed.filter { $0.hasPrefix("count=") }, ["count=2|x\n\n"])
    }

    func testOnceServeReturnsTheCodeOfMain() async throws {
        let url = try script("main() { echo 'No sky' >&2; return 3; }\nopenspot_serve main \"$@\"")
        let process = ScriptProcess(url: url, arguments: ["read"], limit: 5)

        do {
            for try await _ in process.start() {}
            XCTFail("the call did not fail")
        } catch {
            XCTAssertEqual(error as? SpotError, .failed(3, "No sky"))
        }
    }

    func testAValueWithANewLineAndAKeyLineAddsNoRow() async throws {
        let url = try script("""
        bad=$(printf 'one\\n\\nrow=x\\ntitle=x')
        openspot_row a "$bad" "$bad" 'a\\b'
        openspot_kv tone good
        printf 'b\\tBack\\\\slash\\t\\t\\tvalue=true\\tkeyword=c\\\\d\\n' | openspot_rows
        """)

        let output = try await ScriptProcess.output(url: url, limit: 10)

        let items = SpotOutput(text: output).items
        XCTAssertEqual(items.map(\.run), ["a", "b"], output)
        XCTAssertEqual(items.first?.title, "one\n\nrow=x\ntitle=x")
        XCTAssertEqual(items.first?.subtitle, "one\n\nrow=x\ntitle=x")
        XCTAssertEqual(items.last?.title, "Back\\slash")
        XCTAssertEqual(items.last?.isOn, true)
        XCTAssertEqual(items.last?.keywords, ["c\\d"])
        XCTAssertEqual(TextBlock.blocks(in: output).first { $0.value("row") == "a" }?.value("tone"), "good")
    }

    func testAStayingScriptIsNotBlockedAndKeepsItsCallsOnStdin() async throws {
        let url = try script("""
        printf 'a=%s|%s\\n---\\n' "$(esc 'b\\c')" "$(value a)"
        while IFS= read -r line; do
          [ -z "$line" ] || printf 'got=%s\\n---\\n' "$line"
        done
        """, header: "# mode=stay\n")
        let live = ScriptProcess(url: url, mode: .stays, limit: 3)
        defer { live.end() }
        var frames = live.start().makeAsyncIterator()

        let first = try await frames.next()
        live.send(.press("go"), id: 1)
        let second = try await frames.next()

        XCTAssertEqual(first, "a=b\\\\c|\n")
        XCTAssertEqual(second, "got=call=1\n")
    }

    func testAStayingRunHasNoVariableThatNamesItsLife() async throws {
        let url = try script("printf 'stay=%s\\n---\\n' \"${OPENSPOT_STAY-}\"", header: "# mode=stay\n")
        let live = ScriptProcess(url: url, mode: .stays, limit: 3)
        defer { live.end() }
        var frames = live.start().makeAsyncIterator()

        let first = try await frames.next()

        XCTAssertEqual(first, "stay=\n")
    }

    func testTheHelperReadsAllOfStdinInAScriptThatSaysStayFalse() async throws {
        let url = try script("printf '%s' \"$(value a)\"", header: "# title=Once\n# mode=once\n")

        let output = try await ScriptProcess.output(url: url, input: "a=one\n", limit: 5)

        XCTAssertEqual(output, "one")
    }

    func testTheFileInTheBundleOfTheAppComesFirst() throws {
        let contents = folder.appendingPathComponent("Openspot.app/Contents")
        let resources = contents.appendingPathComponent("Resources")
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let file = resources.appendingPathComponent("openspot.sh")
        try "".write(to: file, atomically: true, encoding: .utf8)
        let app = contents.appendingPathComponent("MacOS/Openspot").path

        let environment = ScriptProcess.environment(base: ["HOME": folder.path, "OPENSPOT_SH": "/given"], app: app)

        XCTAssertEqual(environment["OPENSPOT_SH"], file.path)
    }

    func testWithNoFileInTheBundleTheGivenPathStays() {
        let environment = ScriptProcess.environment(base: ["HOME": folder.path, "OPENSPOT_SH": "/given"], app: "/none/Openspot.app/Contents/MacOS/Openspot")

        XCTAssertEqual(environment["OPENSPOT_SH"], "/given")
    }
}
