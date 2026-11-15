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

    func testRecordStartsWithTheInputsOfItsSettingAndTheNextRunStopsAndCopiesTheVideo() async throws {
        let record = try example("Record")
        try await withPrivateHome(["OPENSPOT_SETTING_INPUTS": "mic:B2 system"]) { folder in
            try self.fakeScreen(in: folder)

            let started = try await record.perform(.open, timeout: 60)
            XCTAssertEqual(started, "Recording the screen. Run Record again to stop it.")
            XCTAssertTrue(try self.read("calls", in: folder).contains("screen record start mic:B2 system\n"))
            XCTAssertFalse(try self.read("calls", in: folder).contains("setting get"))

            let stopped = try await record.perform(.open, timeout: 60)
            XCTAssertEqual(stopped, "Copied the recording.")
            XCTAssertEqual(try self.read("clipboard", in: folder), folder.path + "/talk.mp4")
        }
    }

    func testTheInputsSettingListsTheSoundMicsAndCamerasWithTheKeptOnesOn() async throws {
        let record = try example("Record")
        try await withPrivateHome(["OPENSPOT_SETTING_INPUTS": "mic:B2 camera:C3"]) { folder in
            try self.fakeScreen(in: folder)

            let form = try await record.form(CommandAction(id: "inputs", title: "Sound and camera"), item: nil, timeout: 60)

            XCTAssertEqual(record.settings.map(\.id), ["inputs"])
            XCTAssertEqual(form.soleChoice?.options.map(\.id), ["system", "mic:A1", "mic:B2", "camera:C3"])
            XCTAssertEqual(form.soleChoice?.picks, ["mic:B2", "camera:C3"])
        }
    }

    func testAPickTurnsAnInputOnOrOffAndReplacesTheOtherOfItsKind() async throws {
        let record = try example("Record")
        let inputs = SpotAction.action(CommandAction(id: "inputs", title: "Sound and camera"), item: nil)
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)
            let pick = { (input: String, kept: String) in
                _ = try await SpotRuns(environment: TestEnvironment.values).answer(of: record, inputs, input: "inputs=\(input)\n", limit: 60, variables: ["OPENSPOT_SETTING_INPUTS": kept])
                return (try? self.read("setting-inputs", in: folder)) ?? ""
            }

            let first = try await pick("mic:B2", "mic:A1")
            let second = try await pick("system", "mic:B2")
            let third = try await pick("mic:B2", "mic:B2 system")
            let last = try await pick("system", "system")

            XCTAssertEqual([first, second, third], ["mic:B2", "mic:B2 system", "system"])
            XCTAssertEqual(last, "")
        }
    }

    func testAShotThatThePersonCancelsCopiesNothing() async throws {
        let shot = try example("Shot")
        try await withPrivateHome { folder in
            try self.fakeScreen(in: folder)

            let toast = try await shot.perform(.open, timeout: 60)

            XCTAssertNil(toast)
            XCTAssertEqual(try self.read("calls", in: folder), "screen shot\n")
        }
    }

    func testTheEditorOfShotTypeChecks() async throws {
        _ = try await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/swiftc"), arguments: ["-typecheck", examples.appendingPathComponent("shot.spot/edit.swift").path], base: TestEnvironment.values)
    }
}
