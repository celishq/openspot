import XCTest
@testable import OpenspotCore

final class ScreenExamplesTests: SampleSpotsCase {
    private func fakeScreen(in folder: URL) throws {
        let path = folder.path
        try """
        #!/bin/sh
        echo "$*" >> '\(path)/calls'
        key=$3
        [ "$3" = --spot ] && key=$5
        case "$1 $2" in
          'setting get') cat "\(path)/setting-$key" 2>/dev/null ;;
          'setting set') if [ $# -ge 4 ]; then printf '%s' "$4" > "\(path)/setting-$3"; else rm -f "\(path)/setting-$3"; fi ;;
          'screen sources') printf 'row=display:1\\ntitle=Built-in\\n\\nrow=window:7\\ntitle=Notes\\n\\nrow=system\\ntitle=Sound of the Mac\\n\\nrow=mic:A1\\ntitle=Desk\\n\\nrow=mic:B2\\ntitle=Headset\\n\\nrow=camera:C3\\ntitle=FaceTime\\n' ;;
          'screen shot') cat '\(path)/shot' 2>/dev/null || true ;;
          'clipboard copy') printf '%s' "$3" > '\(path)/clipboard' ;;
          'screen record')
            case "$3" in
              status) if [ -f '\(path)/ended' ]; then printf 'state=ended\\nfile=\(path)/talk.mp4\\n'; elif [ -f '\(path)/recording' ]; then printf 'state=recording\\nfile=\(path)/talk.mp4\\n'; else printf 'state=idle\\n'; fi ;;
              start) touch '\(path)/recording' ;;
              stop)
                if [ -f '\(path)/ended' ]; then rm '\(path)/ended'; printf '\(path)/talk.mp4\\n'; echo 'The recording ended as macOS stopped it.' >&2; exit 1; fi
                rm '\(path)/recording'; printf '\(path)/talk.mp4\\n' ;;
            esac ;;
        esac

        """.writeScript(to: folder.appendingPathComponent("tools/openspot"))
    }

    func testRecordStartsWithTheKeptInputsAndTheNextRunStopsAndCopiesTheVideo() async throws {
        let record = try example("Record")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            try "mic:B2 system".write(to: folder.appendingPathComponent("setting-inputs"), atomically: true, encoding: .utf8)

            let started = try await record.perform(.open, timeout: 60)
            XCTAssertEqual(started, "Recording the screen. Run Record again to stop it.")
            XCTAssertTrue(try self.read("calls", in: folder).contains("screen record start mic:B2 system\n"))

            let stopped = try await record.perform(.open, timeout: 60)
            XCTAssertEqual(stopped, "Copied the recording.")
            XCTAssertEqual(try self.read("clipboard", in: folder), folder.path + "/talk.mp4")
        }
    }

    func testRecordStopsARecordingThatMacOSEndedCopiesItsVideoAndSaysWhy() async throws {
        let record = try example("Record")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            FileManager.default.createFile(atPath: folder.appendingPathComponent("ended").path, contents: Data())

            do {
                try await record.perform(.open, timeout: 60)
                XCTFail("the run says why the recording ended")
            } catch {
                XCTAssertTrue("\(error)".contains("The recording ended as macOS stopped it."), "\(error)")
            }

            XCTAssertEqual(try self.read("clipboard", in: folder), folder.path + "/talk.mp4")
            XCTAssertFalse(try self.read("calls", in: folder).contains("screen record start"))
        }
    }

    func testRecordInputsListsTheSoundMicsAndCamerasWithTheKeptOnesOn() async throws {
        let inputs = try example("Record inputs")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            try "mic:B2 camera:C3".write(to: folder.appendingPathComponent("setting-inputs"), atomically: true, encoding: .utf8)

            let items = try await inputs.items(timeout: 60).items

            XCTAssertEqual(items.map(\.run), ["system", "mic:A1", "mic:B2", "camera:C3"])
            XCTAssertEqual(items.filter(\.isOn).map(\.run), ["mic:B2", "camera:C3"])
        }
    }

    func testAPickTurnsAnInputOnOrOffAndReplacesTheOtherOfItsKind() async throws {
        let inputs = try example("Record inputs")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            try "mic:A1".write(to: folder.appendingPathComponent("setting-inputs"), atomically: true, encoding: .utf8)

            try await inputs.perform(.item(SpotItem(title: "Headset", run: "mic:B2")), timeout: 60)
            XCTAssertEqual(try self.read("setting-inputs", in: folder), "mic:B2")
            try await inputs.perform(.item(SpotItem(title: "Sound of the Mac", run: "system")), timeout: 60)
            XCTAssertEqual(try self.read("setting-inputs", in: folder), "mic:B2 system")
            try await inputs.perform(.item(SpotItem(title: "Headset", run: "mic:B2")), timeout: 60)
            XCTAssertEqual(try self.read("setting-inputs", in: folder), "system")
            try await inputs.perform(.item(SpotItem(title: "Sound of the Mac", run: "system")), timeout: 60)
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("setting-inputs").path))
        }
    }

    private func shotEditor(_ folder: URL) -> [String: String] {
        ["editor.swift": """
        import AppKit
        \(Self.note(to: folder))
        final class Editor {
            init(picture: NSImage, file: URL, closed: @escaping () -> Void) {
                note("edit \\(file.lastPathComponent)")
                guard ProcessInfo.processInfo.environment["SHOT_HOLDS"] != "1" else { return }
                DispatchQueue.main.async(execute: closed)
            }
            func front() { note("front") }
            func close() { note("close") }
        }
        """]
    }

    private func shot(in folder: URL, picture: String? = nil, holds: Bool = false) async throws -> (ScriptProcess, SpotFrames) {
        try fakeScreen(in: folder)
        if let picture { try picture.write(to: folder.appendingPathComponent("shot"), atomically: true, encoding: .utf8) }
        let program = try await swiftSpot("shot", in: folder, standIns: shotEditor(folder))
        let script = staying(program, as: "shot", home: folder, variables: ["SHOT_HOLDS": holds ? "1" : ""])
        return (script, SpotFrames(script.start()))
    }

    private func png(in folder: URL) throws -> URL {
        let file = folder.appendingPathComponent("a.png")
        try XCTUnwrap(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==")).write(to: file)
        return file
    }

    func testShotIsAStayingSwiftSpotThatUsesTheScreenAndTheClipboard() throws {
        let shot = try example("Shot")

        XCTAssertEqual(shot.mode, .stay)
        XCTAssertNil(shot.read)
        XCTAssertEqual(shot.sources, ["shot"])
        XCTAssertEqual(shot.uses, [.screen, .clipboard])
    }

    func testAShotThatThePersonCancelsCopiesNothing() async throws {
        let folder = try temporaryFolder()
        let (script, frames) = try await shot(in: folder)
        defer { script.stop() }

        script.send(text: "call=1\narg=open\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(try read("calls", in: folder), "screen shot\n")
        XCTAssertEqual(notes(in: folder), "")
        XCTAssertEqual(frames.toasts, [])
    }

    func testAShotOpensItsEditorInTheCallAndCopiesThePictureWhenTheEditorCloses() async throws {
        let folder = try temporaryFolder()
        let picture = try png(in: folder)
        let (script, frames) = try await shot(in: folder, picture: picture.path + "\n")
        defer { script.stop() }

        script.send(text: "call=1\narg=open\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(notes(in: folder), "edit a.png\n")
        XCTAssertEqual(try read("clipboard", in: folder), picture.path)
        XCTAssertEqual(frames.toasts, ["Copied the picture."])
    }

    func testAPictureThatCannotOpenSaysSoAndCopiesNothing() async throws {
        let folder = try temporaryFolder()
        let file = folder.appendingPathComponent("b.png")
        try "not a picture".write(to: file, atomically: true, encoding: .utf8)
        let (script, frames) = try await shot(in: folder, picture: file.path)
        defer { script.stop() }

        script.send(text: "call=1\narg=open\n\n")
        try await wait("the end of the press") { frames.ends == ["1"] }

        XCTAssertEqual(frames.toasts, ["Openspot cannot open b.png to mark it."])
        XCTAssertEqual(notes(in: folder), "")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("clipboard").path))
    }

    func testASecondPressFrontsTheEditorAndOnlyItsCloseEndsTheCall() async throws {
        let folder = try temporaryFolder()
        let picture = try png(in: folder)
        let (script, frames) = try await shot(in: folder, picture: picture.path, holds: true)
        defer { script.stop() }

        script.send(text: "call=1\narg=open\n\n")
        try await wait("the editor") { self.notes(in: folder) == "edit a.png\n" }
        script.send(text: "call=2\narg=open\n\n")
        try await wait("the end of the second press") { frames.ends == ["2"] }
        script.send(text: "stop=1\n\n")
        try await wait("the editor in front again") { self.notes(in: folder) == "edit a.png\nfront\nfront\n" }

        XCTAssertEqual(frames.ends, ["2"])
        XCTAssertEqual(try read("calls", in: folder), "screen shot\n")
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("clipboard").path))
    }

    func testTheEndOfStdinEndsShotWhileItsEditorShows() async throws {
        let folder = try temporaryFolder()
        let picture = try png(in: folder)
        let (script, frames) = try await shot(in: folder, picture: picture.path, holds: true)
        defer { script.stop() }

        script.send(text: "call=1\narg=open\n\n")
        try await wait("the editor") { self.notes(in: folder) == "edit a.png\n" }
        script.end()

        try await wait("the end of the spot") { !script.isRunning && frames.ended }
    }

    func testTheEditorOfShotTypeChecks() async throws {
        try await typechecks("shot")
    }
}
