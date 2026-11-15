import AppKit
import AVFoundation
import Carbon.HIToolbox

/// The words that Whisper heard, without the tags it writes for sounds, such as `[BLANK_AUDIO]` or `(music)`. A text
/// with no letter or digit, such as the lone `.` that Whisper writes for silence, is no words.
struct Transcript: Equatable {
    let text: String

    init(whisper: String) {
        let lines = whisper.components(separatedBy: .newlines).map { line in
            line.replacingOccurrences(of: #"\[[^\]]*\]"#, with: " ", options: .regularExpression)
        }
        let words = lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !($0.hasPrefix("(") && $0.hasSuffix(")")) && !($0.hasPrefix("*") && $0.hasSuffix("*")) }
            .joined(separator: " ")
        let joined = words.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        text = joined.contains { $0.isLetter || $0.isNumber } ? joined : ""
    }
}

/// The texts that the person dictated, one line each as `<milliseconds>\t<text>`, oldest first. It keeps the last `limit`.
struct History {
    static let limit = 10
    let file: URL

    /// Adds a text with the time it came, and drops the oldest past the limit.
    func add(_ text: String, at date: Date = Date()) {
        let old = (try? String(contentsOf: file, encoding: .utf8))?.split(separator: "\n").map(String.init) ?? []
        let line = "\(Int(date.timeIntervalSince1970 * 1000))\t\(text.replacingOccurrences(of: "\t", with: " "))"
        let kept = (old + [line]).suffix(Self.limit)
        try? (kept.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
    }
}

/// Sound from the microphone as 16 kHz mono samples, which Whisper reads, and its loudness as it comes.
final class Recording {
    static let rate: Double = 16_000
    private var engine: AVAudioEngine?
    private var samples: [Float] = []
    private let lock = NSLock()

    /// Starts the microphone. Each loudness, from 0 to 1, reaches `level` on the main thread. The sound joins `kept`, the
    /// sound of a recording that the person brought back.
    func start(keeping kept: [Float] = [], level: @escaping (Float) -> Void) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.rate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: format, to: target) else { throw CocoaError(.featureUnsupported) }
        lock.withLock { samples = kept }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            let loudness = Self.loudness(buffer)
            DispatchQueue.main.async { level(loudness) }
            let capacity = AVAudioFrameCount(Double(buffer.frameLength) * Self.rate / format.sampleRate) + 16
            guard let out = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var given = false
            converter.convert(to: out, error: nil) { _, status in
                if given { status.pointee = .noDataNow; return nil }
                given = true
                status.pointee = .haveData
                return buffer
            }
            guard let channel = out.floatChannelData?[0] else { return }
            let part = Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
            self.lock.withLock { self.samples += part }
        }
        engine.prepare()
        try engine.start()
        self.engine = engine
    }

    /// Stops the microphone and gives what it heard.
    func stop() -> [Float] {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        return lock.withLock { samples }
    }

    private static func loudness(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += channel[index] * channel[index] }
        let decibels = 20 * log10(max(sqrt(sum / Float(buffer.frameLength)), 1e-6))
        return min(max((decibels + 50) / 32, 0), 1)
    }
}

/// A WAV file of 16-bit samples, as the Whisper server takes it.
struct Wave {
    let data: Data

    init(samples: [Float], rate: Double) {
        var data = Data()
        func put<T>(_ value: T) { withUnsafeBytes(of: value) { data.append(contentsOf: $0) } }
        let bytes = UInt32(samples.count * 2)
        data.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + bytes).littleEndian)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); put(UInt32(16).littleEndian)
        put(UInt16(1).littleEndian); put(UInt16(1).littleEndian)
        put(UInt32(rate).littleEndian); put(UInt32(rate * 2).littleEndian)
        put(UInt16(2).littleEndian); put(UInt16(16).littleEndian)
        data.append(contentsOf: Array("data".utf8)); put(bytes.littleEndian)
        for sample in samples { put(Int16(max(-1, min(1, sample)) * 32_767).littleEndian) }
        self.data = data
    }
}

/// One Whisper server that keeps the model loaded, so a phrase takes about a second and not the load of 1.6 GB.
/// It starts with the first recording, which hides its load, and runs until the spot ends, however the spot ends.
final class Whisper {
    /// Runs the server until the spot's end of its input closes, and ends when the server ends.
    private static let watch = """
        exec 3<&0 </dev/null
        whisper-server "$@" & server=$!
        { read -r line <&3; kill $server; } & link=$!
        wait $server
        kill $link
        """
    private let model: String
    private var process: Process?
    /// The input of the server's watch, whose end only the spot holds.
    private var link: Pipe?
    private var port = 0

    init(model: String) {
        self.model = model
    }

    /// Starts the server if it is not running.
    func start() {
        guard process?.isRunning != true else { return }
        port = Self.freePort()
        let link = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", Self.watch, "sh", "-m", model, "--host", "127.0.0.1", "--port", String(port), "-l", "auto"]
        process.standardInput = link
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        self.process = process
        self.link = link
    }

    /// The words in this sound. It waits up to a minute for the model to load.
    func transcribe(_ wave: Wave) async throws -> String {
        start()
        let boundary = UUID().uuidString
        var body = Data()
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\ntext\r\n".utf8))
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"speech.wav\"\r\nContent-Type: audio/wav\r\n\r\n".utf8))
        body.append(wave.data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/inference")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        let deadline = Date().addingTimeInterval(60)
        while true {
            do {
                let (data, response) = try await URLSession.shared.upload(for: request, from: body)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                return String(decoding: data, as: UTF8.self)
            } catch let error as URLError where error.code == .cannotConnectToHost && Date() < deadline && process?.isRunning == true {
                try await Task.sleep(for: .milliseconds(200))
            }
        }
    }

    func stop() {
        try? link?.fileHandleForWriting.close()
        link = nil
        process = nil
    }

    private static func freePort() -> Int {
        let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        defer { close(socket) }
        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        var size = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(socket, $0, size) } }
        _ = withUnsafeMutablePointer(to: &address) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(socket, $0, &size) } }
        return Int(UInt16(bigEndian: address.sin_port))
    }
}

/// Escape, held for the whole Mac while the pill records, so it discards the recording and reaches no app.
final class EscapeKey {
    private var key: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let press: () -> Void

    init(press: @escaping () -> Void) {
        self.press = press
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            Unmanaged<EscapeKey>.fromOpaque(context!).takeUnretainedValue().press()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }

    func hold() {
        guard key == nil else { return }
        RegisterEventHotKey(UInt32(kVK_Escape), 0, EventHotKeyID(signature: OSType(0x6463_7465), id: 1), GetApplicationEventTarget(), 0, &key)
    }

    func free() {
        if let key { UnregisterEventHotKey(key) }
        key = nil
    }
}


/// One dictation at a time: `start` begins it, and the key or ✓ stops it and shows Transcribing until Whisper reads the
/// words, then hides the pill and pastes them. Escape or ✕ discards it, and the key or a click on the pill brings it
/// back for a few seconds. Silence never stops it. `ended` runs each time it is over, whatever ended it.
final class Dictation {
    enum Phase { case idle, recording, discarded, working }

    private(set) var phase = Phase.idle
    private let recording = Recording()
    private let whisper: Whisper
    private let history: History
    private let ended: () -> Void
    private var pill: Pill!
    private var escape: EscapeKey!
    private let shortest = 0.3
    /// The sound of a discarded dictation, kept for `undoTime` so that the person can bring it back.
    private var kept: [Float] = []
    private var undoTimer: Timer?
    private let undoTime: TimeInterval = 5
    /// The time that the pill shows a message for.
    private let pause: TimeInterval = 2.5

    init(whisper: Whisper, folder: URL, ended: @escaping () -> Void) {
        self.whisper = whisper
        self.ended = ended
        history = History(file: folder.appendingPathComponent("history"))
        pill = Pill(folder: folder, discard: { [weak self] in self?.discard() }, finish: { [weak self] in self?.finish() })
        escape = EscapeKey { [weak self] in
            guard let self else { return }
            phase == .discarded ? drop() : discard()
        }
        Tool.run(["openspot", "setting", "get", "key.dictate"]) { [weak self] _, key, _ in
            self?.pill.key = Self.label(of: key.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// A key as the Mac writes it, such as ⌥ for `option` or ⌃⌥D for `ctrl+option+d`, or nil for no key.
    static func label(of key: String) -> String? {
        guard !key.isEmpty else { return nil }
        let marks = ["cmd": "⌘", "ctrl": "⌃", "option": "⌥", "shift": "⇧"]
        return key.split(separator: "+").map { marks[String($0)] ?? $0.uppercased() }.joined()
    }

    /// A press of the person's key while a dictation runs.
    func toggle() {
        switch phase {
        case .idle: start()
        case .recording: finish()
        case .discarded: resume()
        case .working: break
        }
    }

    /// Starts to record, or ends at once when the microphone cannot record.
    func start() {
        guard phase == .idle else { return }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            phase = .working
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.phase = .idle
                    granted ? self.start() : self.rest()
                }
            }
            return
        case .authorized: break
        default:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            return rest(saying: "Microphone is off")
        }
        do {
            try recording.start { [weak self] level in self?.pill.bars.take(level) }
        } catch {
            return rest(saying: "No microphone")
        }
        phase = .recording
        whisper.start()
        escape.hold()
        pill.record()
    }

    /// Drops the dictation with no undo, as a second press of its card does. A dictation that Whisper reads goes on.
    func stop() {
        guard phase == .recording || phase == .discarded else { return }
        _ = recording.stop()
        undoTimer?.invalidate()
        kept = []
        escape.free()
        pill.hide()
        rest()
    }

    /// Ends the dictation. With a text, the pill says it first, and the dictation ends when the pill hides, so that the
    /// spot does not end before the person reads it.
    private func rest(saying text: String? = nil) {
        guard let text else {
            phase = .idle
            return ended()
        }
        phase = .working
        pill.say(text, for: pause)
        DispatchQueue.main.asyncAfter(deadline: .now() + pause) { self.rest() }
    }

    /// Stops the microphone and keeps the sound for a short time, while the pill offers it back.
    private func discard() {
        guard phase == .recording else { return }
        kept = recording.stop()
        phase = .discarded
        pill.offerUndo(for: undoTime) { [weak self] in self?.resume() }
        undoTimer?.invalidate()
        undoTimer = Timer.scheduledTimer(withTimeInterval: undoTime, repeats: false) { [weak self] _ in self?.drop() }
    }

    /// Brings a discarded dictation back: the microphone starts again, and the new sound joins the old.
    private func resume() {
        guard phase == .discarded else { return }
        undoTimer?.invalidate()
        do {
            try recording.start(keeping: kept) { [weak self] level in self?.pill.bars.take(level) }
        } catch {
            return drop()
        }
        kept = []
        phase = .recording
        pill.record()
    }

    /// Lets a discarded dictation go for good.
    private func drop() {
        guard phase == .discarded else { return }
        undoTimer?.invalidate()
        kept = []
        escape.free()
        pill.hide()
        rest()
    }

    private func finish() {
        guard phase == .recording else { return }
        let samples = recording.stop()
        escape.free()
        guard Double(samples.count) / Recording.rate >= shortest else {
            pill.hide()
            return rest()
        }
        phase = .working
        pill.work()
        let wave = Wave(samples: samples, rate: Recording.rate)
        Task { @MainActor in
            guard let heard = try? await whisper.transcribe(wave) else {
                return rest(saying: "Try again")
            }
            let text = Transcript(whisper: heard).text
            guard !text.isEmpty else {
                return rest(saying: "No words heard")
            }
            history.add(text)
            pill.hide()
            Self.paste(text) { fault in
                guard let fault else { return self.rest() }
                guard !fault.contains("Accessibility") else {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    return self.rest()
                }
                self.rest(saying: "Press ⌘V to paste")
            }
        }
    }

    /// Pastes the text into the front app through the clipboard, then puts back each item that the clipboard held, unless
    /// something else changed the clipboard since. A paste that fails leaves the text on the clipboard, and `done` gets
    /// its fault.
    static func paste(_ text: String, on board: NSPasteboard = .general, done: @escaping (String?) -> Void) {
        let kept = (board.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
        board.clearContents()
        board.setString(text, forType: .string)
        let mark = board.changeCount
        Tool.run(["openspot", "clipboard", "paste"], limit: 5) { code, _, fault in
            guard code == 0 else { return done(fault.isEmpty ? "The paste took too long." : fault) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if board.changeCount == mark {
                    board.clearContents()
                    let items = kept.map { types in
                        let item = NSPasteboardItem()
                        for (type, data) in types { item.setData(data, forType: type) }
                        return item
                    }
                    if !items.isEmpty { board.writeObjects(items) }
                }
                done(nil)
            }
        }
    }
}
