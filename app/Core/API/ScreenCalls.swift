import Foundation

struct ScreenCalls {
    let mac: any Mac
    let environment: [String: String]
    let fence: (caller: CallerTokens.Caller, mode: CarefulMode)?

    private var folder: URL {
        URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    func sources() -> CommandAPI.Work {
        { [mac] in CommandAnswer(output: await mac.screenSources()) }
    }

    func shot(_ capture: ScreenCapture) -> CommandAPI.Work {
        refusal(of: capture) ?? CommandAnswer.work { [mac, folder] in try await mac.screenShot(capture, in: folder) }
    }

    func start(_ capture: ScreenCapture) -> CommandAPI.Work {
        refusal(of: capture) ?? CommandAnswer.work { [mac, folder] in try await mac.startRecording(capture, in: folder) }
    }

    private func refusal(of capture: ScreenCapture) -> CommandAPI.Work? {
        guard let fence else { return nil }
        let own = ProcessInfo.processInfo.environment
        let data = fence.caller.dataName.map { ScriptProcess.dataFolder(base: own, dataName: $0).path }
        for path in [capture.file, capture.events].compactMap({ $0 }) {
            let file = path.hasPrefix("/") ? URL(fileURLWithPath: path) : folder.appendingPathComponent(path)
            let climbs = path.split(separator: "/").contains("..")
            guard climbs || !fence.mode.allows(writing: file, data: data, temp: own["TMPDIR"] ?? NSTemporaryDirectory(), home: own["HOME"] ?? NSHomeDirectory()) else { continue }
            let line = "Careful mode keeps \(fence.caller.name) from writing \(file.path). Name a file in its data folder or a temp folder, or add `uses=files` to its header.\n"
            return { CommandAnswer(errors: line, code: 1) }
        }
        return nil
    }

    func stop() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in try await mac.stopRecording() }
    }

    func status() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in try await mac.recordingStatus() }
    }
}
