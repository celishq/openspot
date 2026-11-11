import Foundation

/// The calls of `openspot screen`, which reach the screen through the Mac. A relative file starts in the working folder of
/// the caller.
struct ScreenCalls {
    let mac: any Mac
    let environment: [String: String]

    private var folder: URL {
        URL(fileURLWithPath: environment["PWD"] ?? FileManager.default.currentDirectoryPath, isDirectory: true)
    }

    func sources() -> CommandAPI.Work {
        { [mac] in CommandAnswer(output: await mac.screenSources()) }
    }

    func shot(_ capture: ScreenCapture) -> CommandAPI.Work {
        CommandAnswer.work { [mac, folder] in try await mac.screenShot(capture, in: folder) }
    }

    func start(_ capture: ScreenCapture) -> CommandAPI.Work {
        CommandAnswer.work { [mac, folder] in try await mac.startRecording(capture, in: folder) }
    }

    func stop() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in try await mac.stopRecording() }
    }

    func status() -> CommandAPI.Work {
        CommandAnswer.work { [mac] in try await mac.recordingStatus() }
    }
}
