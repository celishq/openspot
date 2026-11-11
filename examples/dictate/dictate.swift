import AppKit
import AVFoundation
import Carbon.HIToolbox

/// The words that Whisper heard, without the tags it writes for sounds, such as `[BLANK_AUDIO]` or `(music)`.
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
        text = words.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Sound from the microphone as 16 kHz mono samples, which Whisper reads, and its loudness as it comes.
final class Recording {
    static let rate: Double = 16_000
    private var engine: AVAudioEngine?
    private var samples: [Float] = []
    private let lock = NSLock()

    /// Starts the microphone. Each loudness, from 0 to 1, reaches `level` on the main thread.
    func start(level: @escaping (Float) -> Void) throws {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Self.rate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: format, to: target) else { throw CocoaError(.featureUnsupported) }
        lock.withLock { samples = [] }
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
        return min(max((decibels + 55) / 40, 0), 1)
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
/// It starts with the first recording, which hides its load, and stops after `rest` without use to free its memory.
final class Whisper {
    private let model: String
    private let pidfile: URL
    private let rest: TimeInterval = 600
    private var process: Process?
    private var port = 0
    private var restTimer: Timer?

    init(model: String, folder: URL) {
        self.model = model
        pidfile = folder.appendingPathComponent("whisper.pid")
        if let old = try? String(contentsOf: pidfile, encoding: .utf8), let pid = pid_t(old) { kill(pid, SIGTERM) }
    }

    /// Starts the server if it is not running.
    func start() {
        restTimer?.invalidate()
        guard process?.isRunning != true else { return }
        port = Self.freePort()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["whisper-server", "-m", model, "--host", "127.0.0.1", "--port", String(port), "-l", "auto"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        try? String(process.processIdentifier).write(to: pidfile, atomically: true, encoding: .utf8)
        self.process = process
    }

    /// The words in this sound. It waits up to a minute for the model to load.
    func transcribe(_ wave: Wave) async throws -> String {
        start()
        defer { DispatchQueue.main.async { self.rested() } }
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
        process?.terminate()
        process = nil
        try? FileManager.default.removeItem(at: pidfile)
    }

    private func rested() {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: rest, repeats: false) { [weak self] _ in self?.stop() }
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

/// The clipboard while dictated text is on it. It keeps what the person had copied, and gives it back after `hold`,
/// unless the person copied something new meanwhile.
final class Clipboard {
    private let hold: TimeInterval = 10
    private var kept: [[NSPasteboard.PasteboardType: Data]] = []
    private var mark = 0
    private var timer: Timer?

    /// Puts the text on the clipboard and pastes it into the front app. It is false when the paste needs Accessibility.
    func paste(_ text: String) -> Bool {
        let board = NSPasteboard.general
        if timer == nil {
            kept = (board.pasteboardItems ?? []).map { item in
                Dictionary(uniqueKeysWithValues: item.types.compactMap { type in item.data(forType: type).map { (type, $0) } })
            }
        }
        board.clearContents()
        board.setString(text, forType: .string)
        mark = board.changeCount
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: hold, repeats: false) { [weak self] _ in self?.giveBack() }
        let paste = Process()
        paste.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        paste.arguments = ["openspot", "clipboard", "paste"]
        paste.standardOutput = FileHandle.nullDevice
        paste.standardError = FileHandle.nullDevice
        guard (try? paste.run()) != nil else { return false }
        paste.waitUntilExit()
        return paste.terminationStatus == 0
    }

    private func giveBack() {
        timer = nil
        let board = NSPasteboard.general
        guard board.changeCount == mark else { return }
        board.clearContents()
        let items = kept.map { types in
            let item = NSPasteboardItem()
            for (type, data) in types { item.setData(data, forType: type) }
            return item
        }
        if !items.isEmpty { board.writeObjects(items) }
        kept = []
    }
}

/// The bars that rise with the voice. Each bar has its own share of the loudness, so they move as a wave and not as one.
final class Bars: NSView {
    private let shares: [CGFloat] = [0.45, 0.7, 0.9, 1, 0.85, 1, 0.9, 0.7, 0.45]
    private var bars: [CALayer] = []
    private var level: CGFloat = 0
    private var target: CGFloat = 0
    private var phase: CGFloat = 0
    private var timer: Timer?
    private(set) var isWorking = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        for _ in shares {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = 1.5
            bar.actions = ["bounds": NSNull(), "position": NSNull(), "opacity": NSNull()]
            layer?.addSublayer(bar)
            bars.append(bar)
        }
        draw()
    }

    required init?(coder: NSCoder) { nil }

    /// Takes a new loudness from 0 to 1.
    func take(_ loudness: Float) {
        target = CGFloat(loudness)
    }

    /// Moves the bars at each frame while the pill shows. `working` makes a slow wave that says Whisper is busy.
    func run(working: Bool) {
        isWorking = working
        target = 0
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1 / 60, repeats: true) { [weak self] _ in self?.draw() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func rest() {
        timer?.invalidate()
        timer = nil
        level = 0
        target = 0
        draw()
    }

    private func draw() {
        level += (target - level) * (target > level ? 0.5 : 0.15)
        phase += isWorking ? 0.12 : 0.25
        let width: CGFloat = 3
        let gap: CGFloat = 3
        let whole = CGFloat(shares.count) * width + CGFloat(shares.count - 1) * gap
        let left = (bounds.width - whole) / 2
        for (index, bar) in bars.enumerated() {
            let wave = (sin(phase + CGFloat(index) * 0.7) + 1) / 2
            let share = isWorking ? 0.15 + 0.35 * wave : shares[index] * level * (0.75 + 0.25 * wave)
            let height = max(3, min(bounds.height, 3 + share * (bounds.height - 3)))
            bar.frame = CGRect(x: left + CGFloat(index) * (width + gap), y: (bounds.height - height) / 2, width: width, height: height)
            bar.opacity = isWorking ? 0.6 : 0.95
        }
    }
}

/// A round button of the pill. It takes the first click, so the front app keeps its focus and its cursor.
final class PillButton: NSView {
    private let action: () -> Void
    private let image: NSImageView

    init(symbol: String, label: String, action: @escaping () -> Void) {
        self.action = action
        image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage())
        super.init(frame: CGRect(x: 0, y: 0, width: 28, height: 28))
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.14).cgColor
        image.symbolConfiguration = .init(pointSize: 11, weight: .bold)
        image.contentTintColor = .white
        image.frame = bounds.insetBy(dx: 6, dy: 6)
        addSubview(image)
        setAccessibilityRole(.button)
        setAccessibilityLabel(label)
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.3).cgColor
    }

    override func mouseUp(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.14).cgColor
        if bounds.contains(convert(event.locationInWindow, from: nil)) { action() }
    }
}

/// The pill at the bottom of the screen: ✕, the bars, and ✓. It never takes the focus, so the text lands where the cursor was.
final class Pill {
    let bars: Bars
    private let panel: NSPanel
    private let note = NSTextField(labelWithString: "")
    private let buttons: [NSView]
    private let size = CGSize(width: 148, height: 40)
    private var noteTimer: Timer?

    init(discard: @escaping () -> Void, finish: @escaping () -> Void) {
        panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        let ground = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        ground.material = .hudWindow
        ground.blendingMode = .behindWindow
        ground.state = .active
        ground.appearance = NSAppearance(named: .darkAqua)
        ground.maskImage = Self.capsule(size.height / 2)
        let close = PillButton(symbol: "xmark", label: "Discard", action: discard)
        let done = PillButton(symbol: "checkmark", label: "Paste", action: finish)
        close.frame.origin = CGPoint(x: 6, y: 6)
        done.frame.origin = CGPoint(x: size.width - 34, y: 6)
        bars = Bars(frame: CGRect(x: 38, y: 8, width: size.width - 76, height: size.height - 16))
        note.frame = CGRect(x: 12, y: 11, width: size.width - 24, height: 18)
        note.alignment = .center
        note.font = .systemFont(ofSize: 12, weight: .medium)
        note.textColor = .white
        note.lineBreakMode = .byTruncatingTail
        note.isHidden = true
        buttons = [close, done]
        for view in [close, bars, done, note] { ground.addSubview(view) }
        panel.contentView = ground
        panel.alphaValue = 0.001
        panel.setFrameOrigin(place())
        panel.orderFrontRegardless()
        DispatchQueue.main.async { self.panel.orderOut(nil) }
    }

    /// Shows the pill as it records.
    func record() {
        noteTimer?.invalidate()
        note.isHidden = true
        bars.isHidden = false
        buttons.forEach { $0.isHidden = false }
        bars.run(working: false)
        show()
    }

    /// Shows that Whisper is busy with the words.
    func work() {
        bars.run(working: true)
    }

    /// Shows a short line in place of the bars, then hides the pill.
    func say(_ text: String) {
        bars.rest()
        bars.isHidden = true
        buttons.forEach { $0.isHidden = true }
        note.stringValue = text
        note.isHidden = false
        let width = min(max(note.intrinsicContentSize.width + 32, size.width), 420)
        var frame = panel.frame
        frame.origin.x += (frame.width - width) / 2
        frame.size.width = width
        panel.setFrame(frame, display: true)
        panel.contentView?.frame.size = frame.size
        (panel.contentView as? NSVisualEffectView)?.maskImage = Self.capsule(size.height / 2)
        note.frame.size.width = width - 24
        show()
        noteTimer?.invalidate()
        noteTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in self?.hide() }
    }

    func hide() {
        noteTimer?.invalidate()
        bars.rest()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            panel.animator().alphaValue = 0.001
        }, completionHandler: { [panel] in
            panel.orderOut(nil)
        })
    }

    private func show() {
        if !panel.isVisible || panel.alphaValue < 0.5 {
            panel.setContentSize(size)
            panel.contentView?.frame.size = size
            panel.setFrameOrigin(place())
            panel.alphaValue = 0.001
        }
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    private func place() -> CGPoint {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        let area = screen?.visibleFrame ?? .zero
        return CGPoint(x: area.midX - size.width / 2, y: area.minY + 28)
    }

    private static func capsule(_ radius: CGFloat) -> NSImage {
        let side = radius * 2 + 1
        let image = NSImage(size: CGSize(width: side, height: side), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
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

/// One dictation at a time: the key starts it, and the key or ✓ pastes its words, while Escape or ✕ discards it.
/// Silence never stops it.
final class Dictation {
    enum Phase { case idle, recording, working }

    private(set) var phase = Phase.idle
    private let recording = Recording()
    private let whisper: Whisper
    private let clipboard = Clipboard()
    private var pill: Pill!
    private var escape: EscapeKey!
    private let shortest = 0.3

    init(model: String, folder: URL) {
        whisper = Whisper(model: model, folder: folder)
        pill = Pill(discard: { [weak self] in self?.discard() }, finish: { [weak self] in self?.finish() })
        escape = EscapeKey { [weak self] in self?.discard() }
    }

    /// A press of the person's key.
    func toggle() {
        switch phase {
        case .idle: start()
        case .recording: finish()
        case .working: break
        }
    }

    func stop() {
        whisper.stop()
    }

    private func start() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { if granted { self.start() } }
            }
            return
        case .authorized: break
        default:
            pill.say("Allow Openspot to use the microphone in Settings.")
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            return
        }
        do {
            try recording.start { [weak self] level in self?.pill.bars.take(level) }
        } catch {
            pill.say("Openspot cannot open the microphone.")
            return
        }
        phase = .recording
        whisper.start()
        escape.hold()
        pill.record()
    }

    private func discard() {
        guard phase == .recording else { return }
        _ = recording.stop()
        escape.free()
        phase = .idle
        pill.hide()
    }

    private func finish() {
        guard phase == .recording else { return }
        let samples = recording.stop()
        escape.free()
        guard Double(samples.count) / Recording.rate >= shortest else {
            phase = .idle
            pill.hide()
            return
        }
        phase = .working
        pill.work()
        let wave = Wave(samples: samples, rate: Recording.rate)
        Task { @MainActor in
            defer { phase = .idle }
            guard let heard = try? await whisper.transcribe(wave) else {
                pill.say("Whisper could not read the words. Try again.")
                return
            }
            let text = Transcript(whisper: heard).text
            guard !text.isEmpty else {
                pill.say("Openspot heard no words.")
                return
            }
            if clipboard.paste(text) {
                pill.hide()
            } else {
                pill.say("Copied, but Openspot cannot paste. Press ⌘V.")
            }
        }
    }
}

let arguments = CommandLine.arguments
switch arguments.dropFirst().first {
case "clean":
    let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    print(Transcript(whisper: input).text)
case "wave":
    let samples = arguments.dropFirst(2).compactMap(Float.init)
    FileHandle.standardOutput.write(Wave(samples: samples, rate: Recording.rate).data)
case "stay":
    guard arguments.count >= 4, let parent = pid_t(arguments[2]) else { exit(2) }
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let folder = URL(fileURLWithPath: arguments[0]).deletingLastPathComponent()
    let dictation = Dictation(model: arguments[3], folder: folder)
    signal(SIGUSR1, SIG_IGN)
    signal(SIGTERM, SIG_IGN)
    let press = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
    press.setEventHandler { dictation.toggle() }
    press.resume()
    let end = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    end.setEventHandler { dictation.stop(); exit(0) }
    end.resume()
    let watch = DispatchSource.makeProcessSource(identifier: parent, eventMask: .exit, queue: .main)
    watch.setEventHandler { dictation.stop(); exit(0) }
    watch.resume()
    if kill(parent, 0) != 0 { dictation.stop(); exit(0) }
    if arguments.count > 4, arguments[4] == "start" { DispatchQueue.main.async { dictation.toggle() } }
    app.run()
default:
    exit(2)
}
