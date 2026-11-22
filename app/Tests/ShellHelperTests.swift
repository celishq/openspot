import os
import XCTest
@testable import OpenspotCore

final class ShellHelperTests: XCTestCase {
    private var folder: URL!

    override func setUpWithError() throws {
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-sh-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: folder)
    }

    private func script(_ body: String, shell: String = "/bin/sh", toml: String = "") throws -> URL {
        let name = UUID().uuidString
        let url = folder.appendingPathComponent(name).appendingPathComponent(name)
        try "#!\(shell)\n. \"$OPENSPOT_SH\"\n\(body)\n".writeScript(to: url, toml: toml)
        return url
    }

    private func output(of url: URL, shell: String, input: String, base: [String: String]? = nil) async throws -> String {
        let text = OSAllocatedUnfairLock<String?>(initialState: nil)
        let run = Task {
            let printed = (try? await ScriptProcess.output(url: URL(fileURLWithPath: shell), arguments: [url.path], input: input, base: base)) ?? ""
            text.withLock { $0 = printed }
        }
        defer { run.cancel() }
        try await wait("the end of \(shell)") { text.withLock { $0 } != nil }
        return text.withLock { $0 } ?? ""
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

                let output = try await ScriptProcess.output(url: url, input: input, limit: 60)

                XCTAssertEqual(output, "\(text)|second=\(text)", "\(shell) \(text.debugDescription)")
            }
        }
    }

    func testEscIsTheInverseOfValueInEachShell() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\na=$(value a; printf x)\nprintf 'a=%s\\n' \"$(esc \"${a%x}\")\"", shell: shell)
            for text in Self.hard {
                let line = TextBlock(fields: [.init(key: "a", value: text)]).text

                let output = try await ScriptProcess.output(url: url, input: line, limit: 60)

                XCTAssertEqual(output, line, "\(shell) \(text.debugDescription)")
            }
        }
    }

    func testEscValueAndServeWorkWhereNoTempFileCanBeWritten() async throws {
        let fence = "(version 1)(allow default)(deny file-write* (subpath \"/private/var/tmp\") (subpath \"/private/tmp\") (subpath \"/private/var/folders\"))"
        let once = try script("printf '[%s][%s][%s]' \"$(esc 'a\\b\nc')\" \"$(value a)\" \"$(value b)\"")
        let served = try script("main() { printf '%s|%s|' \"$1\" \"$(value secret)\"; openspot_input; /bin/cat; kept=yes; return 3; }\nopenspot_serve main \"$@\"\nprintf '|%s|%s' \"$?\" \"$kept\"")
        let stays = try script("count=0\nmain() { count=$((count + 1)); printf '%s|%s|%s|%s|' \"$count\" \"$(esc \"$1\")\" \"$#\" \"$(value secret)\"; openspot_input; /bin/cat; }\nopenspot_serve main", toml: "stay = true")
        let tool = URL(fileURLWithPath: "/usr/bin/sandbox-exec")
        let calls = "call=1\narg=a\\\\b\\nc\narg=\nsecret=hunter2\nb=1\n\ncall=2\n\ncall=3\nsecret=two\n\n"

        for shell in ["/bin/sh", "/bin/dash"] {
            let read = try await ScriptProcess.output(url: tool, arguments: ["-p", fence, shell, once.path], input: "a=one\\ntwo\nb=1\nc=2\nb=3\n", limit: 60)
            let ran = try await ScriptProcess.output(url: tool, arguments: ["-p", fence, shell, served.path, "open"], input: "secret=hunter2\nb=1\n", limit: 60)
            let stayed = try await ScriptProcess.output(url: tool, arguments: ["-p", fence, shell, stays.path], input: calls, limit: 60)

            XCTAssertEqual(read, "[a\\\\b\\nc][one\ntwo][1\n3]", shell)
            XCTAssertEqual(ran, "open|hunter2|secret=hunter2\nb=1\n|3|yes", shell)
            XCTAssertTrue(stayed.contains("1|a\\\\b\\nc|2|hunter2|secret=hunter2\nb=1\n"), stayed)
            XCTAssertTrue(stayed.contains("2||0||"), stayed)
            XCTAssertTrue(stayed.contains("3||0|two|secret=two\n"), stayed)
        }
    }

    func testServeWritesNothingInTheTempFolderAlsoWhenACallIsStopped() async throws {
        let temp = folder.appendingPathComponent("temp")
        try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
        let once = try script("main() { printf '%s' \"$(value a)\"; }\nopenspot_serve main")
        let stays = try script("main() { printf '%s' \"$(value a)\"; }\nopenspot_serve main", toml: "stay = true")
        let stopped = try script("main() { kill -TERM $$; }\nopenspot_serve main", toml: "stay = true")
        var base = ProcessInfo.processInfo.environment
        base["TMPDIR"] = temp.path

        for shell in ["/bin/sh", "/bin/dash"] {
            let ran = try await output(of: once, shell: shell, input: "a=1\n", base: base)
            let stayed = try await output(of: stays, shell: shell, input: "call=1\na=1\n\ncall=2\na=2\n\n", base: base)
            _ = try await output(of: stopped, shell: shell, input: "call=1\n\(Self.large)\n\n", base: base)

            XCTAssertEqual(ran, "1", shell)
            XCTAssertTrue(stayed.contains("1\n") && stayed.contains("2\n"), stayed)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: temp.path), [], shell)
        }
    }

    func testValueReadsTheInputOfANameThatStdinLacks() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("printf '%s|%s|%s' \"$(value url)\" \"$(value item)\" \"$(value none)\"", shell: shell)

            let output = try await ScriptProcess.output(url: url, input: "input.url=https://a.example\nitem=own\ninput.item=input\n", limit: 60)

            XCTAssertEqual(output, "https://a.example|own|", shell)
        }
    }

    func testServeKeepsOneProcessForEachCallWhenTheSpotTomlSaysStayTrue() async throws {
        let stays = try script("main() { printf '%s|%s;' \"$$\" \"$(value a)\"; }\nopenspot_serve main", toml: "title = 'Stays'\nstay = true")

        for shell in ["/bin/sh", "/bin/dash"] {
            let stayed = try await output(of: stays, shell: shell, input: "call=1\na=1\n\ncall=2\na=2\n\n")

            XCTAssertTrue(stayed.contains("call=1\n") && stayed.contains("call=2\n"), stayed)
            XCTAssertTrue(stayed.contains("|1;") && stayed.contains("|2;"), stayed)
        }
    }

    private static let large = "a=" + String(repeating: "x", count: 200_000)

    func testACallWithLargeStdinEndsWhateverItsFunctionReads() async throws {
        let url = try script("""
        main() {
          case $1 in
            half) openspot_input | /usr/bin/head -c 100000 | /usr/bin/wc -c ;;
            all) openspot_input | /usr/bin/wc -c ;;
            raw) printf 'raw=%s|\\n' "$(/bin/cat)" ;;
          esac
        }
        openspot_serve main
        """, toml: "stay = true")
        var calls = ""
        for id in 1...20 {
            let word = ["none", "half", "all", "raw"][id % 4]
            calls += "call=\(id)\narg=\(word)\n" + (id % 5 == 0 ? "" : "\(Self.large)\n") + "\n"
        }

        for shell in ["/bin/sh", "/bin/dash"] {
            let output = try await output(of: url, shell: shell, input: calls)

            XCTAssertEqual(output.components(separatedBy: "end=").count - 1, 20, shell)
            XCTAssertEqual(output.components(separatedBy: " 100000\n").count - 1, 4, shell)
            XCTAssertEqual(output.components(separatedBy: " 200003\n").count - 1, 4, shell)
            XCTAssertEqual(output.components(separatedBy: "raw=|\n").count - 1, 5, shell)
        }
    }

    func testServeStartsNoProcessOfItsOwnAndLeavesNoneWhenTheFunctionExits() async throws {
        let stays = try script("main() { /usr/bin/pgrep -P $$ > /dev/null; printf 'none=%s\\n' \"$?\"; }\nopenspot_serve main", toml: "stay = true")
        let once = try script("trap '/usr/bin/pgrep -P $$ > /dev/null; printf none=%s \"$?\"' EXIT\nmain() { exit 0; }\nopenspot_serve main")

        for shell in ["/bin/sh", "/bin/dash"] {
            let stayed = try await output(of: stays, shell: shell, input: "call=1\n\(Self.large)\n\n")
            let ran = try await output(of: once, shell: shell, input: "a=" + String(repeating: "x", count: 200_000) + "\n")

            XCTAssertTrue(stayed.contains("none=1\n"), "\(shell) \(stayed)")
            XCTAssertEqual(ran, "none=1", shell)
        }
    }

    func testAChildOfOneCallGetsNothingOfTheNextAndTheNextNothingOfTheLast() async throws {
        let url = try script("""
        main() {
          case $1 in
            child) /bin/sleep 600 > /dev/null 2>&1 & child=$! ;;
            *) printf 'got=%s|%s|\\n' "$(value b)" "$(/bin/cat)"; kill "$child" ;;
          esac
        }
        openspot_serve main
        """, toml: "stay = true")

        for shell in ["/bin/sh", "/bin/dash"] {
            let output = try await output(of: url, shell: shell, input: "call=1\narg=child\nsecret=old\n\ncall=2\narg=next\nb=new\n\n")

            XCTAssertTrue(output.contains("got=new||\n"), "\(shell) \(output)")
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

        let output = try await ScriptProcess.output(url: url, limit: 60)

        XCTAssertTrue(output.hasPrefix("a\\\\b\\nc|:|one|2"), output)
    }

    func testValueOfARepeatedKeyPrintsEachValueOnItsOwnLineInEachShellAndSize() async throws {
        let padding = String(repeating: "x", count: 2_000)
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\nvalue a", shell: shell)
            for tail in ["", padding] {
                let values = ["one two", "a\\b\nc", "three" + tail]
                let input = TextBlock(fields: values.flatMap { [.init(key: "a", value: $0), .init(key: "b", value: "not this")] }).text

                let output = try await ScriptProcess.output(url: url, input: input, limit: 60)

                XCTAssertEqual(output, values.joined(separator: "\n"), "\(shell) \(tail.count)")
            }
        }
    }

    func testRowsPrintTheValuesOfEachBlockSplitByTabsInEachShell() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("printf 'text=a\\ntitle=A one\\nat=t1\\n\\ntext=b\\nat=t2\\nat=t3\\n' | openspot_rows text at title", shell: shell)

            let output = try await ScriptProcess.output(url: url, limit: 60)

            XCTAssertEqual(output, "a\tt1\tA one\nb\tt2\t\n", shell)
        }
    }

    func testValueOfAnUnknownIdPrintsNothing() async throws {
        let url = try script("value none\nvalue a=\nprintf '%s' \"$(value ''; value a)\"")

        let output = try await ScriptProcess.output(url: url, input: "a=1\n", limit: 60)

        XCTAssertEqual(output, "1")
    }

    func testValueIsSafeWithAStrictScript() async throws {
        let url = try script("set -eu\nvalue none\nvalue a\nesc x")

        let output = try await ScriptProcess.output(url: url, limit: 60)

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

                let output = try await ScriptProcess.output(url: url, input: line, limit: 60)

                XCTAssertEqual(output, TextBlock(fields: [.init(key: "a", value: big)]).text + big, "\(shell) \(text.debugDescription)")
            }
        }
    }

    private static let megabyte = 1_000_000

    private static let megabyteTexts = [
        String(repeating: "a", count: megabyte),
        String(repeating: "\\", count: megabyte),
        String(repeating: "one line\n", count: megabyte / 9),
        String(repeating: String(repeating: "a", count: 99) + "\\", count: megabyte / 100)
    ]

    private func seconds(of url: URL, input: URL, output: URL) throws -> TimeInterval {
        var best = TimeInterval.infinity
        for _ in 0..<3 where best >= 10 {
            best = min(best, try oneRun(of: url, input: input, output: output))
        }
        return best
    }

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

    private static let shownCall = """
    main() {
      printf 'item=t\\ntitle=%s\\n' "$(esc "$#|$1|$2|$(value event)|$(value input.note)|$(openspot_input)$(cat)")"
    }
    openspot_serve main "$@"
    """

    private static func pictures(_ frames: [String]) -> [[TextBlock]] {
        frames.map { TextBlock.blocks(in: $0) }.filter { blocks in blocks.contains { !["call", "end"].contains($0.fields.first?.key ?? "") } }
    }

    func testOneMainRunsUnchangedOnceAndStaying() async throws {
        let action = SpotAction(arguments: ["show", "a b"])
        let input = "event=panel\ninput.note=x\\ny\n"
        let once = try script(Self.shownCall)
        let stays = try script(Self.shownCall, toml: "stay = true")

        var onceText = ""
        for try await frame in ScriptProcess(url: once, arguments: action.arguments, mode: .once(input: input), limit: 60).start() {
            onceText += frame
        }
        let live = ScriptProcess(url: stays, mode: .stays, limit: 60)
        var frames = live.start().makeAsyncIterator()
        live.send(Message(action, given: input), id: 1)
        var stayFrames: [String] = []
        while let frame = try await frames.next() {
            stayFrames.append(frame)
            if TextBlock.blocks(in: frame).first?.value("end") == "1" { break }
        }
        live.end()

        XCTAssertEqual(TextBlock.blocks(in: onceText).first?.value("title"), "2|show|a b|panel|x\ny|event=panel\ninput.note=x\\ny")
        XCTAssertEqual(Self.pictures(stayFrames), [TextBlock.blocks(in: onceText)])
        XCTAssertEqual(TextBlock.blocks(in: stayFrames.first ?? "").first?.value("call"), "1")
    }

    func testServeGivesEachCallOnlyItsOwnVariablesAndSkipsAStop() async throws {
        let url = try script("""
        main() { printf 'got=%s|%s|%s\\n' "$1" "$(value event.value)" "$(value input.a)"; }
        openspot_serve main "$@"
        printf 'over=1\\n'
        """, toml: "stay = true")
        let live = ScriptProcess(url: url, mode: .stays, limit: 60)
        var frames = live.start().makeAsyncIterator()

        live.send(Message(.show, event: ShowEvent(event: "music.track", value: "Song"), inputs: [.init(key: "a", value: "held")]), id: 1)
        live.send(text: SpotAction.stopEvent(id: 1))
        live.send(Message(.press("go")), id: 2)
        live.end()
        var printed: [String] = []
        while let frame = try await frames.next() { printed.append(frame) }

        XCTAssertEqual(printed.filter { $0.hasPrefix("got=") || $0.hasPrefix("over=") }, ["got=show|Song|held\n\n", "got=go||\n\n", "over=1\n"])
        XCTAssertEqual(printed.filter { $0.hasPrefix("end=") }, ["end=1\n", "end=2\n"])
    }

    func testServeKeepsAnEmptyFirstArgument() async throws {
        let url = try script("main() { printf 'count=%s|%s\\n' \"$#\" \"$2\"; }\nopenspot_serve main \"$@\"", toml: "stay = true")
        let live = ScriptProcess(url: url, mode: .stays, limit: 60)
        var frames = live.start().makeAsyncIterator()

        live.send(Message(SpotAction(arguments: ["", "x"])), id: 1)
        live.end()
        var printed: [String] = []
        while let frame = try await frames.next() { printed.append(frame) }

        XCTAssertEqual(printed.filter { $0.hasPrefix("count=") }, ["count=2|x\n\n"])
    }

    func testOnceServeReturnsTheCodeOfMain() async throws {
        let url = try script("main() { echo 'No sky' >&2; return 3; }\nopenspot_serve main \"$@\"")
        let process = ScriptProcess(url: url, arguments: ["show"], limit: 60)

        do {
            for try await _ in process.start() {}
            XCTFail("the call did not fail")
        } catch {
            XCTAssertEqual(error as? SpotError, .failed(3, "No sky"))
        }
    }

    func testAValueWithANewLineAndAKeyLineAddsNoRow() async throws {
        let url = try script("""
        bad=$(printf 'one\\n\\ntext=x\\ntitle=x')
        openspot_item a "$bad" "$bad" 'a\\b'
        openspot_kv tone good
        printf 'b\\tBack\\\\slash\\t\\t\\tvalue=true\\tkeywords=c\\\\d\\n' | openspot_items
        """)

        let output = try await ScriptProcess.output(url: url, limit: 60)

        let items = Frame(text: output).items
        XCTAssertEqual(items.map(\.run), ["a", "b"], output)
        XCTAssertEqual(items.first?.title, "one\n\ntext=x\ntitle=x")
        XCTAssertEqual(items.first?.subtitle, "one\n\ntext=x\ntitle=x")
        XCTAssertEqual(items.last?.title, "Back\\slash")
        XCTAssertEqual(items.last?.isOn, true)
        XCTAssertEqual(items.last?.keywords, ["c\\d"])
        XCTAssertEqual(TextBlock.blocks(in: output).first { $0.value("item") == "a" }?.value("tone"), "good")
    }

    func testAStayingScriptIsNotBlockedAndKeepsItsCallsOnStdin() async throws {
        let url = try script("""
        printf 'a=%s|%s\\n---\\n' "$(esc 'b\\c')" "$(value a)"
        while IFS= read -r line; do
          [ -z "$line" ] || printf 'got=%s\\n---\\n' "$line"
        done
        """, toml: "stay = true")
        let live = ScriptProcess(url: url, mode: .stays, limit: 3)
        defer { live.end() }
        var frames = live.start().makeAsyncIterator()

        let first = try await frames.next()
        live.send(Message(.press("go")), id: 1)
        let second = try await frames.next()

        XCTAssertEqual(first, "a=b\\\\c|\n")
        XCTAssertEqual(second, "got=call=1\n")
    }

    func testAStayingRunHasNoVariableThatNamesItsLife() async throws {
        let url = try script("printf 'stay=%s\\n---\\n' \"${OPENSPOT_STAY-}\"", toml: "stay = true")
        let live = ScriptProcess(url: url, mode: .stays, limit: 3)
        defer { live.end() }
        var frames = live.start().makeAsyncIterator()

        let first = try await frames.next()

        XCTAssertEqual(first, "stay=\n")
    }

    func testTheHelperReadsAllOfStdinInAScriptThatSaysStayFalse() async throws {
        let url = try script("printf '%s' \"$(value a)\"", toml: "title = 'Once'\nmode = 'once'")

        let output = try await ScriptProcess.output(url: url, input: "a=one\n", limit: 60)

        XCTAssertEqual(output, "one")
    }

    func testAScriptReadsAValueOfAGivenTextInEachShell() async throws {
        for shell in ["/bin/sh", "/bin/dash"] {
            let url = try script("PATH=/none\ntext=$(/bin/cat \"$1\"; printf x)\na=$(openspot_value a \"${text%x}\"; printf x)\nprintf '%s|%s' \"${a%x}\" \"$(openspot_value none \"${text%x}\")\"", shell: shell)
            for text in Self.hard {
                let file = folder.appendingPathComponent(UUID().uuidString)
                try TextBlock(fields: [.init(key: "first", value: "not this"), .init(key: "a", value: text)]).text.write(to: file, atomically: true, encoding: .utf8)

                let output = try await ScriptProcess.output(url: url, arguments: [file.path], input: "a=stdin\n", limit: 10)

                XCTAssertEqual(output, "\(text)|", "\(shell) \(text.debugDescription)")
            }
        }
    }

    func testAReadOfAGivenTextLeavesStdinForValue() async throws {
        let url = try script("openspot_value a 'a=given' > /dev/null\nprintf '%s' \"$(value a)\"")

        let output = try await ScriptProcess.output(url: url, input: "a=stdin\n", limit: 10)

        XCTAssertEqual(output, "stdin")
    }

    func testAKeptValueIsTheWholeNewTextOrTheWholeOldOne() async throws {
        let file = folder.appendingPathComponent("state/look")
        let url = try script("""
        openspot_keep "$1" 'first
        line' || exit 1
        printf 'second' | openspot_keep "$1" || exit 2
        for part in "$1".*; do [ -e "$part" ] && exit 3; done
        false | openspot_keep /none/dir/file 2>/dev/null && exit 4
        printf done
        """)

        let output = try await ScriptProcess.output(url: url, arguments: [file.path], limit: 10)

        XCTAssertEqual(output, "done")
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "second")
    }

    func testAKeepThatCannotWriteLeavesTheOldValue() async throws {
        let locked = folder.appendingPathComponent("locked")
        try FileManager.default.createDirectory(at: locked, withIntermediateDirectories: true)
        let file = locked.appendingPathComponent("look")
        try "old".write(to: file, atomically: true, encoding: .utf8)
        chmod(locked.path, 0o555)
        defer { chmod(locked.path, 0o755) }
        let url = try script("openspot_keep \"$1\" new\nprintf 'code=%s' \"$?\"")

        let output = try await ScriptProcess.output(url: url, arguments: [file.path], limit: 10)

        XCTAssertEqual(output, "code=1")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: locked.path), ["look"])
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "old")
    }

    private func clipboard(paste: String, holding text: String?) throws -> (script: URL, board: URL, log: URL) {
        let tools = folder.appendingPathComponent("tools-\(UUID().uuidString)")
        let board = tools.appendingPathComponent("board")
        let log = tools.appendingPathComponent("log")
        try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
        if let text { try text.write(to: board, atomically: true, encoding: .utf8) }
        try """
        #!/bin/sh
        case "$1 $2" in
          'clipboard read') [ -f '\(board.path)' ] && /bin/cat '\(board.path)' ;;
          'clipboard copy') /bin/cat > '\(board.path)' ;;
          'clipboard paste') printf 'pasted=%s\\n' "$(/bin/cat '\(board.path)')" >> '\(log.path)'; \(paste) ;;
        esac
        """.writeScript(to: tools.appendingPathComponent("openspot"))
        let url = try script("PATH='\(tools.path)':$PATH\n_openspot_paste_pause=0\nopenspot_paste \"$1\"\nprintf 'code=%s' \"$?\"")
        return (url, board, log)
    }

    func testAPasteKeepsTheClipboardOfThePerson() async throws {
        for text in ["mine", "two\nlines\n", "back\\slash %s"] {
            let (url, board, log) = try clipboard(paste: "exit 0", holding: text)

            let output = try await ScriptProcess.output(url: url, arguments: ["a snippet\nof two lines"], limit: 10)

            XCTAssertEqual(output, "code=0")
            XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "pasted=a snippet\nof two lines\n")
            XCTAssertEqual(try String(contentsOf: board, encoding: .utf8), text)
        }
    }

    func testAPasteClearsAClipboardThatHeldNoText() async throws {
        for paste in ["exit 0", "exit 1"] {
            let (url, board, log) = try clipboard(paste: paste, holding: nil)

            _ = try await ScriptProcess.output(url: url, arguments: ["a secret"], limit: 10)

            XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "pasted=a secret\n")
            XCTAssertEqual(try String(contentsOf: board, encoding: .utf8), "")
        }
    }

    func testAPasteThatFailsStillPutsTheClipboardBackAndFails() async throws {
        let (url, board, _) = try clipboard(paste: "echo 'toast=Openspot cannot paste.'; exit 1", holding: "mine")

        let output = try await ScriptProcess.output(url: url, arguments: ["a snippet"], limit: 10)

        XCTAssertEqual(output, "toast=Openspot cannot paste.\ncode=1")
        XCTAssertEqual(try String(contentsOf: board, encoding: .utf8), "mine")
    }

    func testAPasteWaitsBeforeItPutsTheClipboardBack() async throws {
        let (url, _, _) = try clipboard(paste: "exit 0", holding: "mine")
        let text = try String(contentsOf: url, encoding: .utf8).replacingOccurrences(of: "_openspot_paste_pause=0\n", with: "sleep() { printf 'sleep=%s|' \"$1\"; }\n")
        try text.writeScript(to: url)

        let output = try await ScriptProcess.output(url: url, arguments: ["a snippet"], limit: 10)

        XCTAssertEqual(output, "sleep=0.3|code=0")
    }

    func testEachSpotRunsWithAUTF8LocaleAndTheCommonPaths() async throws {
        let url = try script("printf '%s|%s|' \"$LC_ALL\" \"$PATH\"\nprintf 'ÅÄö' | /usr/bin/tr '[:upper:]' '[:lower:]'")

        let output = try await ScriptProcess.output(url: url, limit: 10, base: ["HOME": folder.path, "PATH": "/usr/bin:/mine", "LC_ALL": "C", "OPENSPOT_SH": try XCTUnwrap(ProcessInfo.processInfo.environment["OPENSPOT_SH"])])

        let parts = output.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(parts.first, "en_US.UTF-8")
        XCTAssertEqual(parts.dropFirst().first?.split(separator: ":").dropFirst().map(String.init), ["/usr/bin", "/mine", "/opt/homebrew/bin", "/usr/local/bin", "/bin", "/usr/sbin", "/sbin"])
        XCTAssertEqual(parts.last, "åäö")
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
