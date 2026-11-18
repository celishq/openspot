#!/usr/bin/env swift

// Openspot builds this file with the Swift files of `dictate/`, and keeps one process while the sheet shows, while the
// menu bar shows Dictate, or while a dictation or the download of the speech model runs. Each of those two is one call
// that stays open until it ends. A second press of the Dictate key finishes a dictation, and a second press of the card
// or of the download row stops it. The texts, the model and the place of the pill stay in the data folder.
//
// The speech model loads with the first dictation and stays loaded only while the process runs. Put Dictate in the menu
// bar to keep it loaded, so that each dictation starts at once.
import AppKit

let data = URL(fileURLWithPath: ProcessInfo.processInfo.environment["OPENSPOT_DATA"] ?? FileManager.default.currentDirectoryPath)
let model = data.appendingPathComponent("ggml-large-v3-turbo.bin")
let history = data.appendingPathComponent("history")
let whisper = Whisper(model: model.path)
var dictation: Dictation?
var download: Download?
/// The call that holds the dictation or the download that runs.
var held: String?

/// The past texts, newest first, as `(stamp, text)`.
func texts() -> [(String, String)] {
    let lines = ((try? String(contentsOf: history, encoding: .utf8)) ?? "").split(separator: "\n")
    return lines.reversed().prefix(History.limit).compactMap { line in
        guard let tab = line.firstIndex(of: "\t") else { return nil }
        return (String(line[..<tab]), String(line[line.index(after: tab)...]))
    }
}

/// How long ago a stamp in milliseconds was, such as `5 min ago` or `3 Nov`.
func age(_ stamp: String) -> String {
    let date = Date(timeIntervalSince1970: (Double(stamp) ?? 0) / 1000)
    let seconds = Int(Date().timeIntervalSince(date))
    if seconds < 60 { return "Just now" }
    if seconds < 3600 { return "\(seconds / 60) min ago" }
    if seconds < 86400 { return "\(seconds / 3600) h ago" }
    let format = DateFormatter()
    format.locale = Locale(identifier: "en_US_POSIX")
    format.dateFormat = "d MMM"
    return format.string(from: date)
}

func percent(_ share: Double) -> String {
    "\(Int(share * 100))% of 1.6 GB"
}

/// The rows of the sheet: the download of the model while it is missing, then the past texts.
func sheet() -> String {
    var blocks: [String] = []
    if !FileManager.default.fileExists(atPath: model.path) {
        if let download {
            blocks.append("row=whisper\ntitle=Downloading speech model\ndetail=\(percent(download.share))\nicon=arrow.down.circle\nopen=Stop\nclose=false\nhides=delete\npin=top")
        } else {
            blocks.append("row=whisper\ntitle=Download speech model\ndetail=1.6 GB\nicon=arrow.down.circle\nopen=Download\nclose=false\nhides=delete\npin=top")
        }
    }
    let past = texts()
    if past.isEmpty {
        blocks.append("search=off")
    } else {
        blocks.append("button=open\ntitle=Copy")
        blocks.append("button=delete\ntitle=Delete\nshortcut=cmd+backspace")
        blocks += past.map { "row=\($0.0)\ntitle=\(Link.value($0.1))\ndetail=\(age($0.0))" }
    }
    return blocks.joined(separator: "\n\n")
}

/// Ends the held call and shows the rows that it changed.
func release() {
    guard let id = held else { return }
    held = nil
    Link.end(id)
    Link.frame(sheet())
}

/// Shows the share of the download on the card while its call runs. Its frames hold only a head, so that the card shows
/// the call as running.
func show(_ share: Double, in id: String) {
    Link.start(id)
    Link.frame("progress=\(String(format: "%.3f", share))\ntitle=Downloading speech model\ndetail=\(percent(share))")
}

/// Downloads the model in a call that stays open until the model lands. The rows come before the call's own output.
func fetch(in id: String, toast: String? = nil) {
    held = id
    download = Download(to: model, progress: { share in show(share, in: id) }) { end in
        download = nil
        Link.start(id)
        switch end {
        case .landed: Link.frame("toast=Dictate is ready. Press your Dictate key to speak.")
        case .failed: Link.frame("toast=Openspot cannot download the speech model. Press Download again to go on from where it stopped.")
        case .wrongSize: Link.frame("toast=The speech model came in the wrong size, so Dictate removed it. Press Download to fetch it again.")
        case .stopped: break
        }
        release()
    }
    Link.frame(sheet())
    show(download?.share ?? 0, in: id)
    if let toast { Link.frame("toast=\(toast)") }
}

/// A press of the Dictate key, or Return on the card: starts a dictation in this call, or finishes the one that runs.
func dictate(_ id: String) {
    if let dictation, dictation.phase != .idle {
        dictation.toggle()
        return answer(id)
    }
    guard Tool.path(of: "whisper-server") != nil else {
        return answer(id, "toast=Openspot cannot find the speech engine. Install it with `brew install whisper-cpp`.")
    }
    guard FileManager.default.fileExists(atPath: model.path) else {
        guard let download else { return fetch(in: id, toast: "Dictate is downloading its speech model of 1.6 GB.") }
        return answer(id, "toast=Dictate is downloading its speech model: \(Int(download.share * 100))%.")
    }
    if dictation == nil { dictation = Dictation(whisper: whisper, folder: data, ended: release) }
    held = id
    Link.start(id)
    dictation?.start()
}

/// Answers a call with one frame, or none, and ends it.
func answer(_ id: String, _ frame: String? = nil) {
    Link.start(id)
    if let frame { Link.frame(frame) }
    Link.end(id)
}

/// Copies a past text.
func copy(_ stamp: String, in id: String) {
    guard let text = texts().first(where: { $0.0 == stamp })?.1 else { return answer(id) }
    Tool.run(["openspot", "clipboard", "copy"], input: text) { code, _, fault in
        answer(id, "toast=\(code == 0 ? "Copied" : Link.value(fault.trimmingCharacters(in: .whitespacesAndNewlines)))")
    }
}

func delete(_ stamp: String) {
    let lines = ((try? String(contentsOf: history, encoding: .utf8)) ?? "").split(separator: "\n").filter { !$0.hasPrefix("\(stamp)\t") }
    try? (lines.map { $0 + "\n" }.joined()).write(to: history, atomically: true, encoding: .utf8)
}

func serve() {
    Link.listen { call in
        let row = call.arguments.dropFirst().first ?? ""
        switch call.arguments.first {
        case "show":
            answer(call.id, sheet())
        case "dictate":
            dictate(call.id)
        case "open" where row == "whisper" && download == nil && !FileManager.default.fileExists(atPath: model.path):
            fetch(in: call.id)
        case "open" where row == "whisper" && download != nil:
            download?.stop()
            answer(call.id)
        case "open" where row != "whisper":
            copy(row, in: call.id)
        case "delete":
            delete(row)
            answer(call.id, sheet())
        case "serve":
            // Starts Whisper with no recording, as a recording does, for a test.
            whisper.start()
            answer(call.id)
        default:
            answer(call.id)
        }
    } stop: { id in
        guard id == held else { return }
        if let download {
            download.stop()
        } else {
            dictation?.stop()
        }
    } end: {
        download?.pause()
        whisper.stop()
        exit(0)
    }
    NSApplication.shared.setActivationPolicy(.accessory)
    NSApplication.shared.run()
}

let arguments = CommandLine.arguments
switch arguments.dropFirst().first {
case "clean":
    let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    print(Transcript(whisper: input).text)
case "place":
    guard arguments.count == 5, let x = Double(arguments[3]), let y = Double(arguments[4]) else { exit(2) }
    let area = CGRect(x: 0, y: 0, width: 1000, height: 700)
    let kept = PillPlace(text: arguments[2]) ?? .standard
    let dropped = PillPlace(pointer: CGPoint(x: x, y: y), in: area)
    func words(_ frame: CGRect) -> String { "\(Int(frame.minX)) \(Int(frame.minY)) \(Int(frame.width)) \(Int(frame.height))" }
    print("\(kept.text) \(words(kept.frame(long: 150, short: 32, in: area))) | \(dropped.text) \(words(dropped.frame(long: 150, short: 32, in: area)))")
case "remember":
    guard arguments.count == 5, let time = Double(arguments[3]) else { exit(2) }
    History(file: URL(fileURLWithPath: arguments[2])).add(arguments[4], at: Date(timeIntervalSince1970: time))
case "wave":
    let samples = arguments.dropFirst(2).compactMap(Float.init)
    FileHandle.standardOutput.write(Wave(samples: samples, rate: Recording.rate).data)
case "paste":
    guard arguments.count == 4 else { exit(2) }
    Dictation.paste(arguments[3], on: NSPasteboard(name: .init(arguments[2]))) { fault in
        print(fault ?? "")
        exit(0)
    }
    dispatchMain()
case "key":
    print(Dictation.label(of: arguments.count > 2 ? arguments[2] : "") ?? "")
case "preview":
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let pill = Pill(folder: data, discard: { exit(0) }, finish: { exit(0) })
    pill.key = "⌥"
    var phase = 0.0
    let voice = Timer(timeInterval: 1 / 30, repeats: true) { _ in
        phase += 1 / 30
        pill.bars.take(Float(max(0, 0.55 + 0.35 * sin(phase * 5.3) * sin(phase * 1.7))))
    }
    RunLoop.main.add(voice, forMode: .common)
    func round() {
        pill.record()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            pill.offerUndo(for: 5) {}
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            pill.record()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 7) {
            pill.work()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                pill.hide()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { round() }
            }
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { round() }
    print("Previewing the pill. Click ✕ or ✓, or press Control-C, to stop.")
    app.run()
default:
    serve()
}
