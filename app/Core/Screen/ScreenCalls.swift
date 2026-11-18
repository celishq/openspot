import Foundation

struct ScreenCalls {
    let mac: (any MacScreen)?
    let folder: URL
    let fence: (caller: Spot, mode: CarefulMode)?

    func sources() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in ScreenDevice.rows(of: try await Self.screen(mac).devices()) }
    }

    func shot(_ capture: ScreenCapture) -> CommandAPI.Work {
        refusal(of: capture) ?? CommandAnswer.work { [mac, folder] in try await Self.screen(mac).shot(capture, in: folder).map { $0.path + "\n" } ?? "" }
    }

    func start(_ capture: ScreenCapture) -> CommandAPI.Work {
        refusal(of: capture) ?? CommandAnswer.work { [mac, folder] in
            try await Self.screen(mac).startRecording(capture, in: folder)
            return ""
        }
    }

    private func refusal(of capture: ScreenCapture) -> CommandAPI.Work? {
        guard let fence else { return nil }
        let own = ProcessInfo.processInfo.environment
        let data = fence.caller.dataName.map { ScriptProcess.dataFolder(base: own, dataName: $0).path }
        for path in [capture.file, capture.events].compactMap({ $0 }) {
            let file = path.hasPrefix("/") ? URL(fileURLWithPath: path) : folder.appendingPathComponent(path)
            let climbs = path.split(separator: "/").contains("..")
            guard climbs || !fence.mode.allows(writing: file, data: data, temp: own["TMPDIR"] ?? NSTemporaryDirectory(), home: own["HOME"] ?? NSHomeDirectory()) else { continue }
            let line = "Careful mode keeps \(fence.caller.name) from writing \(file.path). Name a file in its data folder or a temp folder, or add `files` to `uses` in its spot.toml.\n"
            return { CommandAnswer(errors: line, code: 1) }
        }
        return nil
    }

    func stop() -> CommandAPI.Work {
        { [mac] in
            do { return try await Self.screen(mac).stopRecording().stopAnswer } catch { return CommandAnswer(failure: error) }
        }
    }

    func status() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in ScreenRecording.status(of: try await Self.screen(mac).recording()) }
    }

    private static func screen(_ mac: (any MacScreen)?) throws -> any MacScreen {
        try Mac.part(mac, "screen")
    }
}
