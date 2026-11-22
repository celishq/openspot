import XCTest
@testable import OpenspotCore

@MainActor
final class SpotTypesTests: SpotRunsCase {
    private func types(_ id: String, in spots: URL) async throws -> CommandAnswer {
        let places = AppPlaces.test(["OPENSPOT_CONFIG": folder.appendingPathComponent("config").path, "OPENSPOT_SPOTS": spots.path])
        let api = CommandAPI(mac: Mac(), places: places, runs: nil, rates: .offline)
        let work = try XCTUnwrap(api.work(for: CommandRequest(arguments: ["types", id], folder: spots.path), input: { "" }))
        return await work()
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private var tsc: URL? {
        let paths = ["/opt/homebrew/bin", "/usr/local/bin"] + (TestEnvironment.values["PATH"] ?? "").split(separator: ":").map(String.init)
        return paths.map { URL(fileURLWithPath: $0).appendingPathComponent("tsc") }.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    private func check(_ file: URL, with tsc: URL) async throws -> String {
        let flags = "--noEmit --allowJs --checkJs --strict --target es2022 --module es2022 --moduleResolution bundler --lib es2022"
        return try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "\"$0\" \(flags) \"$1\"; echo \"exit=$?\"", tsc.path, file.path], limit: 300, base: TestEnvironment.values)
    }

    func testTheDeclarationsOfAJSSpotPassItsHandlersAndFailAnUndeclaredInput() async throws {
        guard let tsc else { throw XCTSkip("tsc is not installed on this Mac.") }
        try write("[actions.pick]\ninputs.when = 'text'\noutputs.until = { type = 'date', required = true }", to: folder.appendingPathComponent("picker.spot/spot.toml"))
        try "#!/bin/sh\necho out.until=2026-11-23\n".writeScript(to: folder.appendingPathComponent("picker.spot/picker.sh"))
        let toml = """
        uses = ["timer", "clipboard"]
        [settings]
        step = { type = "number", default = "1" }
        [actions.snooze]
        inputs.url = { type = "url", required = true }
        outputs.until = "date"
        [actions.wake]
        inputs.url = "url"
        [events.snoozed]
        url = { type = "url", required = true }
        until = "date"
        [bindings]
        picker = { spot = "picker" }
        [on]
        command = ["snooze"]
        """
        try write(toml, to: folder.appendingPathComponent("snoozer.spot/spot.toml"))
        let spot = folder.appendingPathComponent("snoozer.spot/snoozer.js")
        try write("export default {}", to: spot)

        let answer = try await types("snoozer", in: folder)

        XCTAssertEqual(answer.code, 0, answer.errors)
        XCTAssertEqual(answer.output, folder.appendingPathComponent("snoozer.spot/openspot.d.ts").path + "\n")
        try write("""
        export default /** @satisfies {import("./openspot").Handlers} */ ({
          async snooze({ url }, env) {
            const picked = await env.picker.pick({ when: "soon" })
            if (!picked) return
            await env.timer.add(picked.until, "wake", { url })
            await env.emit("snoozed", { url, until: picked.until })
            await env.clipboard.read()
            return { until: picked.until }
          },
          async wake({ url }) { return `text=${url}\\ntitle=${url}\\n` },
          async command({ name, text }, env) { return `text=${name}\\ntitle=${text} ${env.settings.step + 1}\\n` },
        })
        """, to: spot)
        let wrong = folder.appendingPathComponent("wrong.js")
        try write("""
        export default /** @satisfies {import("./snoozer.spot/openspot").Handlers} */ ({
          async snooze({ uri }) { return { until: uri } },
        })
        """, to: wrong)

        let passed = try await check(spot, with: tsc)
        let failed = try await check(wrong, with: tsc)

        XCTAssertTrue(passed.hasSuffix("exit=0\n"), passed)
        XCTAssertFalse(failed.hasSuffix("exit=0\n"), failed)
        XCTAssertTrue(failed.contains("'uri'"), failed)
    }

    func testASwiftSpotBuiltAgainstItsTypesAddsATimer() async throws {
        let client = folder.appendingPathComponent("A.app/Contents/Helpers/openspot")
        try FileManager.default.createDirectory(at: client.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: Bundle(for: Self.self).bundleURL.deletingLastPathComponent().appendingPathComponent("openspot"), to: client)
        var environment = TestEnvironment.values
        environment["PATH"] = client.deletingLastPathComponent().path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        let timers = folder.appendingPathComponent("timers.json")
        runs.quit()
        runs = SpotRuns(environment: environment, clock: clock.value, stopPause: 0.2, timers: timers)
        takeCalls()
        let typed = folder.appendingPathComponent("typed")
        let toml = "[actions.go]\n[actions.wake]\ninputs.url = 'url'"
        try write("uses = ['timer']\nsource = ['Openspot.swift']\n" + toml, to: typed.appendingPathComponent("waker.spot/spot.toml"))
        let main = """
        struct Waker: Handlers {
            func go(_ input: GoInput, _ env: Env) async throws -> Answer<NoOutputs> {
                _ = try await env.timer.add("2030-01-01T09:00:00Z", "wake", ["url": "https://example.com/a"])
                return .none
            }
        }

        await Openspot.serve(Waker())
        """
        try main.writeScript(to: typed.appendingPathComponent("waker.spot/waker.swift"))

        let answer = try await types("waker", in: typed)

        XCTAssertEqual(answer.code, 0, answer.errors)
        let build = folder.appendingPathComponent("build")
        try write(main, to: build.appendingPathComponent("main.swift"))
        let program = folder.appendingPathComponent("runner.spot/runner")
        try write("uses = ['timer']\n" + toml, to: folder.appendingPathComponent("runner.spot/spot.toml"))
        let sources = [build.appendingPathComponent("main.swift").path, typed.appendingPathComponent("waker.spot/Openspot.swift").path]
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-Onone"] + sources + ["-o", program.path], limit: 300, base: TestEnvironment.values)
        _ = try scanned()

        _ = try await XCTUnwrap(runs.sheets["runner"]).call("go")

        try await wait("the timer of the Swift spot") {
            let text = (try? String(contentsOf: timers, encoding: .utf8)) ?? ""
            return text.contains("wake") && text.contains("example.com")
        }
    }
}
