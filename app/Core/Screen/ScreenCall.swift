import Foundation

public enum ScreenCall: NounCall {
    case sources
    case shot(ScreenCapture)
    case recordStart(ScreenCapture)
    case recordStop
    case recordStatus

    private static let recording = "used a screen recording"

    static let noun = CommandNoun("screen", group: .mac, guide: "screen", verbs: [
        CommandVerb("sources", "", "Prints each display, window, microphone and camera as a row, with its source as the id: display:<id>, window:<id>, mic:<id>, camera:<id>.", rule: CallRule(use: .screen, used: "listed the screens and windows")) { $0.none ? Self.sources : nil },
        CommandVerb(
            "shot", "[source] [--cursor] [file]",
            "Takes a picture and prints its path. A source is display, window, window:front or area:x,y,w,h; with no value the person picks one, and with no source any. With no file, it goes where macOS keeps screenshots.",
            rule: CallRule(use: .screen, used: "took a screenshot", read: .captures, flags: .events)
        ) { words in
            ScreenCapture(words: words.rest, records: false).map(Self.shot)
        },
        CommandVerb(
            "record start", "[source] [input]... [--cursor] [--events file] [file]",
            "Starts a recording to .mp4 or .mov. An input is mic, system or camera, or mic:<id> or camera:<id>; the camera goes to its own file beside it. --events writes each pointer move, click and key as a JSON line.",
            rule: CallRule(use: .screen, used: recording, read: .captures, flags: .events)
        ) { words in
            ScreenCapture(words: words.rest, records: true).map(Self.recordStart)
        },
        CommandVerb("record stop", "", "Ends the recording and prints each file, the video first.", rule: CallRule(use: .screen, used: recording, read: .captures, flags: .events)) { $0.none ? Self.recordStop : nil },
        CommandVerb("record status", "", "Prints state=recording with its files and seconds, or state=idle.", rule: CallRule(use: .screen, used: recording, flags: .events)) { $0.none ? Self.recordStatus : nil }
    ])

    func work(in context: CallContext) -> CommandAPI.Work? {
        let screen = ScreenCalls(mac: context.mac.screen, folder: context.folder, fence: context.fence)
        return switch self {
        case .sources: screen.sources()
        case .shot(let capture): screen.shot(capture)
        case .recordStart(let capture): screen.start(capture)
        case .recordStop: screen.stop()
        case .recordStatus: screen.status()
        }
    }
}
