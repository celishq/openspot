import Foundation

/// The calls of `openspot screen`, which reach the screen through the Mac. A relative file starts in the working folder of
/// the caller. In Careful mode, a spot with no `files` use takes a capture only into a file that its own process could
/// write, and any other file is refused (Z8).
struct ScreenCalls {
    let mac: any Mac
    let environment: [String: String]
    /// The spot that calls and the folders of its process in Careful mode, or nil when it may write anywhere.
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

    /// The answer that refuses a capture into a file that the calling spot's own process could not write, or nil. A path
    /// with `..` is refused, because the system follows a link before it climbs.
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
