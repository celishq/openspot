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
              status) if [ -f '\(path)/recording' ]; then printf 'state=recording\\nfile=\(path)/talk.mp4\\n'; else printf 'state=idle\\n'; fi ;;
              start) touch '\(path)/recording' ;;
              stop) rm '\(path)/recording'; printf '\(path)/talk.mp4\\n' ;;
            esac ;;
        esac

        """.writeScript(to: folder.appendingPathComponent("tools/openspot"))
    }

    func testRecordStartsWithTheKeptInputsAndTheNextRunStopsAndCopiesTheVideo() async throws {
        let record = try example("Record")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            try "mic:B2 system".write(to: folder.appendingPathComponent("setting-inputs"), atomically: true, encoding: .utf8)

            let started = try await record.perform(.open, timeout: 5)
            XCTAssertEqual(started, "Recording the screen. Run Record again to stop it.")
            XCTAssertTrue(try self.read("calls", in: folder).contains("screen record start mic:B2 system\n"))

            let stopped = try await record.perform(.open, timeout: 5)
            XCTAssertEqual(stopped, "Copied the recording.")
            XCTAssertEqual(try self.read("clipboard", in: folder), folder.path + "/talk.mp4")
        }
    }

    func testRecordInputsListsTheSoundMicsAndCamerasWithTheKeptOnesOn() async throws {
        let inputs = try example("Record inputs")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            try "mic:B2 camera:C3".write(to: folder.appendingPathComponent("setting-inputs"), atomically: true, encoding: .utf8)

            let items = try await inputs.items(timeout: 5).items

            XCTAssertEqual(items.map(\.run), ["system", "mic:A1", "mic:B2", "camera:C3"])
            XCTAssertEqual(items.filter(\.isOn).map(\.run), ["mic:B2", "camera:C3"])
        }
    }

    func testAPickTurnsAnInputOnOrOffAndReplacesTheOtherOfItsKind() async throws {
        let inputs = try example("Record inputs")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            try "mic:A1".write(to: folder.appendingPathComponent("setting-inputs"), atomically: true, encoding: .utf8)

            try await inputs.perform(.item(SpotItem(title: "Headset", run: "mic:B2")), timeout: 5)
            XCTAssertEqual(try self.read("setting-inputs", in: folder), "mic:B2")
            try await inputs.perform(.item(SpotItem(title: "Sound of the Mac", run: "system")), timeout: 5)
            XCTAssertEqual(try self.read("setting-inputs", in: folder), "mic:B2 system")
            try await inputs.perform(.item(SpotItem(title: "Headset", run: "mic:B2")), timeout: 5)
            XCTAssertEqual(try self.read("setting-inputs", in: folder), "system")
            try await inputs.perform(.item(SpotItem(title: "Sound of the Mac", run: "system")), timeout: 5)
            XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("setting-inputs").path))
        }
    }

    func testAShotThatThePersonCancelsCopiesNothing() async throws {
        let shot = try example("Shot")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)

            let toast = try await shot.perform(.open, timeout: 5)

            XCTAssertNil(toast)
            XCTAssertEqual(try self.read("calls", in: folder), "screen shot\n")
        }
    }

    func testTheEditorOfShotTypeChecks() async throws {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-typecheck", examples.appendingPathComponent("shot.spot/edit.swift").path])
    }
}
