import XCTest
@testable import OpenspotCore

/// Proves the Dictate example: the words it keeps from Whisper, the sound it sends, and how its script wakes the helper.
final class DictateExampleTests: SamplePluginsCase {
    private static let model = "ggml-large-v3-turbo.bin"

    /// The data folder of the spot, with a stand-in Whisper server on the `PATH` and a stand-in helper that runs this
    /// body. The helper's file is newer than the source, so the script does not build it.
    private func fakeHelper(_ body: String, model: Bool = true, in folder: URL) throws -> URL {
        try "#!/bin/sh\nexit 0\n".writeScript(to: folder.appendingPathComponent("tools/whisper-server"))
        let data = folder.appendingPathComponent(".config/openspot/data/dictate")
        try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
        try "#!/bin/sh\n\(body)\n".writeScript(to: data.appendingPathComponent("dictate"))
        if model { try Data().write(to: data.appendingPathComponent(Self.model)) }
        return data
    }

    private func helper() async throws -> (URL, URL) {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-dictate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let helper = folder.appendingPathComponent("dictate")
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-o", helper.path, examples.appendingPathComponent("dictate/dictate.swift").path])
        return (folder, helper)
    }

    private func waitFor(_ url: URL) async throws {
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: url.path) {
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    func testTheHelperKeepsTheWordsAndDropsTheTagsOfSounds() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appendingPathComponent("heard")
        try " [BLANK_AUDIO]\n Привіт, світе.\n (soft music)\n  Second   line [Music] here.\n *laughs*\n".write(to: input, atomically: true, encoding: .utf8)

        let text = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "'\(helper.path)' clean < '\(input.path)'"])
        let silence = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf ' [BLANK_AUDIO]\\n' | '\(helper.path)' clean"])

        XCTAssertEqual(text, "Привіт, світе. Second line here.\n")
        XCTAssertEqual(silence, "\n")
    }

    func testTheHelperSendsSixteenBitMonoSoundAtSixteenKilohertz() async throws {
        let (folder, helper) = try await helper()
        defer { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appendingPathComponent("speech.wav")

        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "'\(helper.path)' wave 0 1 -1 2 > '\(file.path)'"])
        let wave = try Data(contentsOf: file)

        func number(_ at: Int, _ size: Int) -> Int { wave[at..<at + size].reversed().reduce(0) { $0 << 8 | Int($1) } }
        XCTAssertEqual(String(decoding: wave[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: wave[8..<16], as: UTF8.self), "WAVEfmt ")
        XCTAssertEqual(number(22, 2), 1)
        XCTAssertEqual(number(24, 4), 16_000)
        XCTAssertEqual(number(34, 2), 16)
        XCTAssertEqual(number(40, 4), 8)
        XCTAssertEqual([number(44, 2), number(46, 2), number(48, 2), number(50, 2)], [0, 32_767, 32_769, 32_767])
    }

    func testAPressWakesTheHelperThatWaitsAndStartsNoOther() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let pressed = folder.appendingPathComponent("pressed")
            let started = folder.appendingPathComponent("started")
            let data = try self.fakeHelper("touch '\(started.path)'", in: folder)
            let waiting = Process()
            waiting.executableURL = URL(fileURLWithPath: "/bin/sh")
            waiting.arguments = ["-c", "trap 'touch \(pressed.path)' USR1; while [ ! -f \(pressed.path) ]; do sleep 0.05; done"]
            try waiting.run()
            defer { waiting.terminate(); waiting.waitUntilExit() }
            try String(waiting.processIdentifier).write(to: data.appendingPathComponent("dictate.pid"), atomically: true, encoding: .utf8)

            _ = try await dictate.perform(.press("dictate"), timeout: 5)
            try await self.waitFor(pressed)

            XCTAssertTrue(FileManager.default.fileExists(atPath: pressed.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: started.path))
        }
    }

    func testAPressWithNoHelperStartsOneThatRecordsAtOnce() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let started = folder.appendingPathComponent("started")
            _ = try self.fakeHelper("echo \"$1 $4\" > '\(started.path)'", in: folder)

            _ = try await dictate.perform(.press("dictate"), timeout: 5)
            try await self.waitFor(started)

            XCTAssertEqual(try self.read("started", in: folder), "stay start\n")
        }
    }

    func testAPressWithNoModelDownloadsItAndRecordsNothing() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let started = folder.appendingPathComponent("started")
            let data = try self.fakeHelper("touch '\(started.path)'", model: false, in: folder)

            let toast = try await dictate.perform(.press("dictate"), timeout: 5)
            try await self.waitFor(folder.appendingPathComponent("fetched"))
            for _ in 0..<100 where FileManager.default.fileExists(atPath: data.appendingPathComponent("download.pid").path) {
                try await Task.sleep(for: .milliseconds(50))
            }

            XCTAssertEqual(toast, "Openspot is downloading the Whisper model, 0% of 1.6 GB. Press the key again once it is done.")
            XCTAssertEqual(try self.read("fetched", in: folder), "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(Self.model)\n")
            XCTAssertFalse(FileManager.default.fileExists(atPath: started.path))
        }
    }

    func testAReadWithNoReasonStartsNoHelper() async throws {
        let dictate = try example("Dictate")
        try await withPrivateHome { folder in
            let data = try self.fakeHelper("touch '\(folder.path)/started'", in: folder)

            _ = try await dictate.items(timeout: 5)

            XCTAssertFalse(FileManager.default.fileExists(atPath: data.appendingPathComponent("dictate.pid").path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("started").path))
        }
    }
}
