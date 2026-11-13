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

/// The download of the Whisper model into the spot's data folder, with its progress from 0 to 1. The bytes go to a `.part`
/// file beside the model, so a download that breaks, or a helper that restarts, goes on from the bytes it has. A server
/// that cannot resume sends the whole file again. The model lands only whole.
final class ModelDownload: NSObject, URLSessionDataDelegate {
    static let source = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin")!
    /// The size of the model, for a server that does not say it.
    static let size: Int64 = 1_624_555_275

    private let target: URL
    private let part: URL
    private let progress: (Double) -> Void
    private let end: (Bool) -> Void
    private(set) var share: Double = 0
    private var session: URLSession?
    private var file: FileHandle?
    /// The bytes on disk, at the start the bytes that a broken download left.
    private(set) var have: Int64 = 0
    private var whole: Int64 = ModelDownload.size

    init(from source: URL = ModelDownload.source, to target: URL, progress: @escaping (Double) -> Void, end: @escaping (Bool) -> Void) {
        self.target = target
        part = target.appendingPathExtension("part")
        self.progress = progress
        self.end = end
        super.init()
        try? FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        have = (try? FileManager.default.attributesOfItem(atPath: part.path)[.size] as? Int64) ?? 0
        share = min(Double(have) / Double(whole), 1)
        var request = URLRequest(url: source)
        if have > 0 { request.setValue("bytes=\(have)-", forHTTPHeaderField: "Range") }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        session.dataTask(with: request).resume()
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 200
        guard status == 200 || status == 206 else { return completionHandler(.cancel) }
        if status != 206 {
            have = 0
            try? FileManager.default.removeItem(at: part)
        }
        if !FileManager.default.fileExists(atPath: part.path) { FileManager.default.createFile(atPath: part.path, contents: nil) }
        file = try? FileHandle(forWritingTo: part)
        _ = try? file?.seekToEnd()
        if response.expectedContentLength > 0 { whole = have + response.expectedContentLength }
        completionHandler(file == nil ? .cancel : .allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        do {
            try file?.write(contentsOf: data)
        } catch {
            return dataTask.cancel()
        }
        have += Int64(data.count)
        share = min(Double(have) / Double(whole), 1)
        progress(share)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        try? file?.close()
        file = nil
        session.finishTasksAndInvalidate()
        self.session = nil
        let isWhole = error == nil && have > 0 && have == whole
        if isWhole {
            try? FileManager.default.removeItem(at: target)
            try? FileManager.default.moveItem(at: part, to: target)
        }
        let landed = isWhole && FileManager.default.fileExists(atPath: target.path)
        if landed { share = 1 }
        end(landed)
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

    /// Puts the text on the clipboard and pastes it into the front app. It gives the fault of a paste that failed, such as
    /// one that needs Accessibility, and nothing when the paste ran.
    func paste(_ text: String) -> String? {
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
        let fault = Pipe()
        paste.standardOutput = FileHandle.nullDevice
        paste.standardError = fault
        guard (try? paste.run()) != nil else { return "Openspot cannot find its openspot command." }
        let words = String(decoding: fault.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        paste.waitUntilExit()
        return paste.terminationStatus == 0 ? nil : words
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

/// The dots that rise into bars with the voice. Each has its own share of the loudness, the middle ones most, and in
/// silence a soft wave runs through them, so the pill shows that it still listens. `turn` lays them in a row up to 0.5
/// and in a column after it, drawn in as dots at 0.5, as the pill turns.
final class Bars: NSView {
    static let count = 13
    static let width: CGFloat = 2.5
    static let gap: CGFloat = 2.5
    static var length: CGFloat { CGFloat(count) * width + CGFloat(count - 1) * gap }

    private let shares: [CGFloat] = (0..<Bars.count).map { index in
        let distance = (CGFloat(index) - CGFloat(Bars.count - 1) / 2) / (CGFloat(Bars.count) / 3.6)
        return 0.06 + 0.94 * exp(-distance * distance)
    }
    /// How fast each bar sways while the voice holds it up, so the bars move apart and not as one block.
    private let tempos: [CGFloat] = (0..<Bars.count).map { index in 3.1 + CGFloat((index * 7) % 5) * 0.55 }
    private var bars: [CALayer] = []
    private var level: CGFloat = 0
    private var target: CGFloat = 0
    private var phase: CGFloat = 0
    private var timer: Timer?

    var turn: CGFloat = 0 {
        didSet { draw() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        for _ in shares {
            let bar = CALayer()
            bar.backgroundColor = NSColor.white.cgColor
            bar.cornerRadius = Self.width / 2
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

    /// Moves the bars at each frame while the pill shows.
    func run() {
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
        level += (target - level) * (target > level ? 0.65 : 0.22)
        phase += 0.06
        let isColumn = turn > 0.5
        let fullness = abs(1 - 2 * turn)
        let along = isColumn ? bounds.height : bounds.width
        let side = isColumn ? bounds.width : bounds.height
        let squeeze = min(max((along - 72) / Self.length, 0), 1)
        let room = max(side - 12 - Self.width, 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, bar) in bars.enumerated() {
            let wave = (sin(phase - CGFloat(index) * 0.5) + 1) / 2
            let sway = (sin(phase * tempos[index] + CGFloat(index) * 1.3) + 1) / 2
            let share = max(shares[index] * level * (0.55 + 0.45 * sway), 0.14 * wave * (1 - level) * shares[index])
            let extent = Self.width + share * room * fullness
            let offset = (CGFloat(index) - CGFloat(Self.count - 1) / 2) * (Self.width + Self.gap) * squeeze
            let frame = isColumn
                ? CGRect(x: bounds.midX - extent / 2, y: bounds.midY - offset - Self.width / 2, width: extent, height: Self.width)
                : CGRect(x: bounds.midX + offset - Self.width / 2, y: bounds.midY - extent / 2, width: Self.width, height: extent)
            bar.frame = frame
            bar.opacity = Float(0.55 + 0.45 * min(1, share * 2))
        }
        CATransaction.commit()
    }
}

/// What the pill shows while Whisper reads: the word Transcribing and three dots that blink in turn. In a column there is
/// no room for the word, so only the dots show, one above the other. The blink runs in Core Animation, off the main thread.
final class Transcribing: NSView {
    private let word = NSTextField(labelWithString: "Transcribing")
    /// The mask of the word, whose bright band sweeps across it.
    private let shine = CAGradientLayer()
    private var dots: [CALayer] = []
    private let size: CGFloat = 4
    private let gap: CGFloat = 4

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        word.font = .systemFont(ofSize: 12, weight: .medium)
        word.textColor = .white
        word.sizeToFit()
        word.wantsLayer = true
        shine.colors = [NSColor(white: 1, alpha: 0.55).cgColor, NSColor.white.cgColor, NSColor(white: 1, alpha: 0.55).cgColor]
        shine.startPoint = CGPoint(x: 0, y: 0.5)
        shine.endPoint = CGPoint(x: 1, y: 0.5)
        shine.locations = [0, 0.5, 1]
        word.layer?.mask = shine
        addSubview(word)
        for _ in 0..<3 {
            let dot = CALayer()
            dot.backgroundColor = NSColor.white.cgColor
            dot.cornerRadius = size / 2
            dot.opacity = 0.4
            dot.actions = ["bounds": NSNull(), "position": NSNull()]
            layer?.addSublayer(dot)
            dots.append(dot)
        }
    }

    required init?(coder: NSCoder) { nil }

    /// Starts the blink, each dot a third of a beat after the one before.
    /// Starts the motion at once: a soft bright band sweeps across the word and on over the dots, and each dot brightens,
    /// swells and rises a little exactly while the band passes over it, so the word and the dots move as one light.
    func blink() {
        let beat: CFTimeInterval = 2.4
        let steps = 72
        let word = max(self.word.frame.width, 1)
        let band: Double = 0.32
        let from = -0.3, to = 1.75
        let centres = (0...steps).map { from + (to - from) * Self.eased(Double($0) / Double(steps)) }
        let start = centres.firstIndex { $0 >= 0.05 }.map { Double($0) / Double(steps) } ?? 0
        for (index, dot) in dots.enumerated() {
            let place = Double((self.word.frame.width + 3 + size / 2 + CGFloat(index) * (size + gap)) / word)
            let light = centres.map { exp(-pow(($0 - place) / band, 2)) }
            let glow = CAKeyframeAnimation(keyPath: "opacity")
            glow.values = light.map { 0.4 + 0.6 * $0 }
            let swell = CAKeyframeAnimation(keyPath: "transform.scale")
            swell.values = light.map { 1 + 0.12 * $0 }
            let lift = CAKeyframeAnimation(keyPath: "position.y")
            lift.values = light.map { 1.2 * $0 }
            lift.isAdditive = true
            let pass = CAAnimationGroup()
            pass.animations = [glow, swell, lift]
            pass.duration = beat
            pass.repeatCount = .infinity
            pass.timeOffset = beat * start
            dot.add(pass, forKey: "blink")
        }
        shine.frame = self.word.bounds
        let sweep = CAKeyframeAnimation(keyPath: "locations")
        sweep.values = centres.map { [$0 - band, $0, $0 + band] }
        sweep.duration = beat
        sweep.repeatCount = .infinity
        sweep.timeOffset = beat * start
        shine.add(sweep, forKey: "blink")
    }

    /// The share of the way that the light has gone at a share of the beat: slow to start, smooth through the middle, slow
    /// to stop, on the curve (0.45, 0, 0.55, 1).
    private static func eased(_ share: Double) -> Double {
        func point(_ t: Double, _ a: Double, _ b: Double) -> Double { 3 * a * t * (1 - t) * (1 - t) + 3 * b * t * t * (1 - t) + t * t * t }
        var low = 0.0, high = 1.0
        for _ in 0..<30 {
            let middle = (low + high) / 2
            if point(middle, 0.45, 0.55) < share { low = middle } else { high = middle }
        }
        return point((low + high) / 2, 0, 1)
    }

    func rest() {
        dots.forEach {
            $0.removeAnimation(forKey: "blink")
        }
        shine.removeAnimation(forKey: "blink")
    }

    /// Lays out the word and the dots in a row, or only the dots in a column.
    func lay(column: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        word.isHidden = column
        let run = 3 * size + 2 * gap
        if column {
            for (index, dot) in dots.enumerated() {
                dot.frame = CGRect(x: bounds.midX - size / 2, y: bounds.midY + run / 2 - size - CGFloat(index) * (size + gap), width: size, height: size)
            }
        } else {
            let whole = word.frame.width + 3 + run
            let left = bounds.midX - whole / 2
            word.frame.origin = CGPoint(x: left, y: bounds.midY - word.frame.height / 2)
            for (index, dot) in dots.enumerated() {
                dot.frame = CGRect(x: left + word.frame.width + 3 + CGFloat(index) * (size + gap), y: bounds.midY - size / 2 - 3, width: size, height: size)
            }
        }
        CATransaction.commit()
    }
}

/// [key] Undo, which a discarded dictation shows in place of its dots: the person's Dictate key in a key cap and the word, in
/// a row, or only the key cap in a column. With no key known, the cap shows ↺.
final class UndoLabel: NSView {
    private let cap = NSTextField(labelWithString: "↺")
    private let word = NSTextField(labelWithString: "Undo")
    private let capBack = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        capBack.backgroundColor = NSColor(white: 1, alpha: 0.22).cgColor
        capBack.cornerRadius = 5
        capBack.cornerCurve = .continuous
        layer?.addSublayer(capBack)
        cap.font = .systemFont(ofSize: 11, weight: .semibold)
        cap.textColor = .white
        cap.alignment = .center
        word.font = .systemFont(ofSize: 12, weight: .medium)
        word.textColor = .white
        word.sizeToFit()
        addSubview(cap)
        addSubview(word)
        setAccessibilityRole(.button)
        setAccessibilityLabel("Undo")
    }

    required init?(coder: NSCoder) { nil }

    /// Fills the bounds of the pill and centres the key cap, with the word beside it in a row.
    func lay(key: String?, column: Bool, in bounds: CGRect) {
        frame = bounds
        cap.stringValue = key ?? "↺"
        cap.sizeToFit()
        word.isHidden = column
        let capSize = CGSize(width: max(cap.frame.width + 10, 20), height: 18)
        let gap: CGFloat = 6
        let whole = column ? capSize.width : capSize.width + gap + word.frame.width
        let left = bounds.midX - whole / 2
        let capFrame = CGRect(x: left, y: bounds.midY - capSize.height / 2, width: capSize.width, height: capSize.height)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        capBack.frame = capFrame
        CATransaction.commit()
        cap.frame = CGRect(x: capFrame.minX, y: capFrame.midY - cap.frame.height / 2, width: capFrame.width, height: cap.frame.height)
        word.frame.origin = CGPoint(x: capFrame.maxX + gap, y: bounds.midY - word.frame.height / 2)
    }
}

/// The person's Dictate key as the Mac writes it, such as ⌥ or ⌥D, read from Openspot's config beside the data folder.
struct DictateKey {
    static func label(near folder: URL) -> String? {
        let config = folder.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("config.toml")
        guard let text = try? String(contentsOf: config, encoding: .utf8) else { return nil }
        for block in text.components(separatedBy: "[[keys]]").dropFirst() {
            let lines = block.components(separatedBy: "\n").prefix { !$0.hasPrefix("[") }
            func value(_ key: String) -> String? {
                lines.first { $0.hasPrefix("\(key) = ") }.map { $0.dropFirst(key.count + 3).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            }
            guard value("spot")?.hasSuffix("dictate") == true, value("command") == "dictate", let key = value("key") else { continue }
            let marks = ["cmd": "⌘", "ctrl": "⌃", "option": "⌥", "shift": "⇧"]
            return key.split(separator: "+").map { marks[String($0)] ?? $0.uppercased() }.joined()
        }
        return nil
    }
}

/// A round button of the pill. It takes the first click, so the front app keeps its focus and its cursor.
final class PillButton: NSView {
    private let action: () -> Void
    private let image: NSImageView

    init(symbol: String, label: String, action: @escaping () -> Void) {
        self.action = action
        image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: label) ?? NSImage())
        super.init(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor(white: 1, alpha: 0.14).cgColor
        image.symbolConfiguration = .init(pointSize: 10, weight: .bold)
        image.contentTintColor = .white
        image.frame = bounds.insetBy(dx: 5, dy: 5)
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

/// The blur of the pill. A drag on it, or on the dots, moves the pill along the edges of the screen.
final class Ground: NSVisualEffectView {
    var drag: (CGPoint) -> Void = { _ in }
    var drop: () -> Void = {}
    /// A click with no drag, such as on the undo of a discarded dictation.
    var click: () -> Void = {}
    private var dragged = false
    /// Whether the pointer shows a hand over the pill, while a click on it does something.
    var pointsAt = false {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .mouseMoved, .activeAlways, .inVisibleRect], owner: self))
    }

    override func cursorUpdate(with event: NSEvent) {
        (pointsAt ? NSCursor.pointingHand : NSCursor.arrow).set()
    }

    override func mouseMoved(with event: NSEvent) {
        (pointsAt ? NSCursor.pointingHand : NSCursor.arrow).set()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        dragged = true
        drag(NSEvent.mouseLocation)
    }

    override func mouseUp(with event: NSEvent) {
        dragged ? drop() : click()
    }
}

/// Where the pill rests: an edge of the screen, and the share along that edge where its middle lies. On the left and right
/// edges it stands as a column. The file keeps it as words, such as `bottom 0.5000`.
struct PillPlace: Equatable {
    enum Edge: String, CaseIterable {
        case bottom, top, left, right
    }

    static let standard = PillPlace(edge: .bottom, along: 0.5)
    /// The room between the pill and the edge of the screen.
    static let gap: CGFloat = 8

    let edge: Edge
    let along: CGFloat

    init(edge: Edge, along: CGFloat) {
        self.edge = edge
        self.along = min(max(along, 0), 1)
    }

    init?(text: String) {
        let words = text.split(separator: " ")
        guard words.count == 2, let edge = Edge(rawValue: String(words[0])), let along = Double(words[1]) else { return nil }
        self.init(edge: edge, along: CGFloat(along))
    }

    /// The place at the edge nearest the pointer, with the pill's middle under it.
    init(pointer: CGPoint, in area: CGRect) {
        let distances: [(Edge, CGFloat)] = [
            (.bottom, pointer.y - area.minY), (.top, area.maxY - pointer.y),
            (.left, pointer.x - area.minX), (.right, area.maxX - pointer.x)
        ]
        let edge = distances.min { $0.1 < $1.1 }!.0
        let along = edge.isUpright ? (pointer.y - area.minY) / max(area.height, 1) : (pointer.x - area.minX) / max(area.width, 1)
        self.init(edge: edge, along: along)
    }

    var text: String {
        String(format: "%@ %.4f", edge.rawValue, along)
    }

    /// The frame of a pill whose row is `long` by `short` points, at this place in the area and wholly inside it.
    func frame(long: CGFloat, short: CGFloat, in area: CGRect) -> CGRect {
        let size = edge.isUpright ? CGSize(width: short, height: long) : CGSize(width: long, height: short)
        func centred(_ start: CGFloat, _ length: CGFloat, _ own: CGFloat) -> CGFloat {
            min(max(start + along * length - own / 2, start + Self.gap), start + length - own - Self.gap)
        }
        let origin = switch edge {
        case .bottom: CGPoint(x: centred(area.minX, area.width, size.width), y: area.minY + Self.gap)
        case .top: CGPoint(x: centred(area.minX, area.width, size.width), y: area.maxY - size.height - Self.gap)
        case .left: CGPoint(x: area.minX + Self.gap, y: centred(area.minY, area.height, size.height))
        case .right: CGPoint(x: area.maxX - size.width - Self.gap, y: centred(area.minY, area.height, size.height))
        }
        return CGRect(origin: origin, size: size)
    }
}

extension PillPlace.Edge {
    var isUpright: Bool { self == .left || self == .right }
}

/// The pill on an edge of the screen: ✕, the dots, and ✓, in a row on the top and bottom edges and in a column on the
/// sides. It never takes the focus, so the text lands where the cursor was. A drag slides it along the edges, and a turn
/// from row to column is one eased motion of its frame, its buttons and its dots.
final class Pill {
    let bars: Bars
    private let panel: NSPanel
    private let ground: Ground
    private let note = NSTextField(labelWithString: "")
    private let close: PillButton
    private let done: PillButton
    private let transcribing = Transcribing(frame: .zero)
    private let undoLabel = UndoLabel(frame: .zero)
    private let fill = CALayer()
    private let short: CGFloat = 32
    private let long = Bars.length + 72
    private let motionTime: CFTimeInterval = 0.24
    private let file: URL
    private var place: PillPlace
    private var turn: CGFloat = 0
    private var goal: (frame: CGRect, turn: CGFloat) = (.zero, 0)
    private var motion: (frame: CGRect, turn: CGFloat, start: CFTimeInterval)?
    private var motionTimer: Timer?
    private var noteTimer: Timer?
    /// Counts each show and hide, so a fade that ends after a later show leaves the pill on the screen.
    private var showing = 0
    /// What a click on the pill does while it offers one, such as undo.
    private var onClick: (() -> Void)?
    private var bloomTimer: Timer?
    /// The full frame of a pill that shrinks, so a show that comes during the shrink grows back to it.
    private var bloomWhole: CGRect?

    init(folder: URL, discard: @escaping () -> Void, finish: @escaping () -> Void) {
        file = folder.appendingPathComponent("place")
        place = (try? String(contentsOf: file, encoding: .utf8)).flatMap(PillPlace.init(text:)) ?? .standard
        let size = CGSize(width: long, height: short)
        panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        ground = Ground(frame: CGRect(origin: .zero, size: size))
        ground.material = .hudWindow
        ground.blendingMode = .behindWindow
        ground.state = .active
        ground.appearance = NSAppearance(named: .darkAqua)
        ground.maskImage = Self.capsule(short / 2)
        ground.autoresizingMask = [.width, .height]
        close = PillButton(symbol: "xmark", label: "Discard", action: discard)
        done = PillButton(symbol: "checkmark", label: "Paste", action: finish)
        bars = Bars(frame: ground.bounds)
        note.alignment = .center
        note.font = .systemFont(ofSize: 12, weight: .medium)
        note.textColor = .white
        note.lineBreakMode = .byTruncatingTail
        note.isHidden = true
        transcribing.isHidden = true
        ground.wantsLayer = true
        fill.backgroundColor = NSColor(white: 1, alpha: 0.18).cgColor
        fill.isHidden = true
        ground.layer?.addSublayer(fill)
        undoLabel.isHidden = true
        for view in [bars, close, done, transcribing, note, undoLabel] { ground.addSubview(view) }
        panel.contentView = ground
        ground.drag = { [weak self] pointer in self?.drag(to: pointer) }
        ground.drop = { [weak self] in self?.keep() }
        ground.click = { [weak self] in self?.onClick?() }
        panel.alphaValue = 0.001
        rest()
        panel.orderFrontRegardless()
        DispatchQueue.main.async { self.panel.orderOut(nil) }
    }

    /// Shows the pill as it records.
    func record() {
        let wasUndo = !undoLabel.isHidden && panel.isVisible
        onClick = nil
        ground.pointsAt = false
        noteTimer?.invalidate()
        note.isHidden = true
        transcribing.rest()
        transcribing.isHidden = true
        bars.isHidden = false
        close.isHidden = false
        done.isHidden = false
        bars.run()
        guard wasUndo else {
            undoLabel.isHidden = true
            Self.stopDrain(fill)
            for view in [bars, close, done] as [NSView] { view.alphaValue = 1 }
            return show()
        }
        for view in [bars, close, done] as [NSView] { view.alphaValue = 0 }
        crossfade(in: [bars, close, done], out: [undoLabel]) { [weak self] in
            guard let self, undoLabel.alphaValue < 0.5 else { return }
            undoLabel.isHidden = true
            Self.stopDrain(fill)
        }
        fade(fill, to: 0)
    }

    /// Fades some parts of the pill in and others out together, in place of a jump between two states.
    private func crossfade(in arriving: [NSView], out leaving: [NSView], then end: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for view in arriving { view.animator().alphaValue = 1 }
            for view in leaving { view.animator().alphaValue = 0 }
        }, completionHandler: end)
    }

    private func fade(_ layer: CALayer, to opacity: Float) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = layer.presentation()?.opacity ?? layer.opacity
        fade.toValue = opacity
        fade.duration = 0.25
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.opacity = opacity
        layer.add(fade, forKey: "fade")
    }

    /// Takes the countdown off the light and hides it, ready for a download's fill.
    private static func stopDrain(_ fill: CALayer) {
        fill.removeAnimation(forKey: "drain")
        fill.removeAnimation(forKey: "fade")
        fill.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        fill.opacity = 1
        fill.isHidden = true
    }

    /// Shows Transcribing with its dots in place of the buttons and the bars, while Whisper reads the words.
    func work() {
        let leaving: [NSView] = [bars, close, done]
        transcribing.alphaValue = 0
        transcribing.isHidden = false
        transcribing.lay(column: turn > 0.5)
        transcribing.blink()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            for view in leaving { view.animator().alphaValue = 0 }
            transcribing.animator().alphaValue = 1
        }, completionHandler: { [weak self] in
            guard let self, !transcribing.isHidden else { return }
            bars.rest()
            for view in leaving { view.isHidden = true }
        })
    }

    /// Shows a short line in place of the dots, in a row beside the pill's edge, then hides the pill after `time`.
    func say(_ text: String, for time: TimeInterval = 2.5) {
        onClick = nil
        line(text, share: nil, for: time)
    }

    /// Offers a discarded dictation back for `time`, in the pill's own size: the Dictate key and Undo in place of the dots,
    /// or only the key in a column, while the pill's light drains away and the pointer shows a hand over it. A click on the pill calls `undo`, and the pill hides when the time is up.
    func offerUndo(for time: TimeInterval, undo: @escaping () -> Void) {
        for view in [transcribing, note] as [NSView] { view.isHidden = true }
        undoLabel.alphaValue = 0
        undoLabel.isHidden = false
        undoLabel.lay(key: DictateKey.label(near: file.deletingLastPathComponent()), column: turn > 0.5, in: ground.bounds)
        ground.pointsAt = true
        crossfade(in: [undoLabel], out: [bars, close, done]) { [weak self] in
            guard let self, !undoLabel.isHidden, undoLabel.alphaValue > 0.5 else { return }
            bars.rest()
            for view in [bars, close, done] as [NSView] { view.isHidden = true }
        }
        fill.removeAnimation(forKey: "fade")
        fill.opacity = 0
        fill.isHidden = false
        fade(fill, to: 1)
        let column = turn > 0.5
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.anchorPoint = column ? CGPoint(x: 0.5, y: 0) : CGPoint(x: 0, y: 0.5)
        fill.frame = ground.bounds
        CATransaction.commit()
        let drain = CABasicAnimation(keyPath: column ? "bounds.size.height" : "bounds.size.width")
        drain.fromValue = column ? ground.bounds.height : ground.bounds.width
        drain.toValue = 0
        drain.duration = time
        drain.fillMode = .forwards
        drain.isRemovedOnCompletion = false
        fill.add(drain, forKey: "drain")
        onClick = undo
        noteTimer?.invalidate()
        noteTimer = Timer.scheduledTimer(withTimeInterval: time, repeats: false) { [weak self] _ in self?.hide() }
    }

    /// Shows the download of the model: its words, and the pill filling from the left as it comes.
    func download(_ share: Double) {
        line(Self.downloadWords(share), share: share, for: 4)
    }

    /// Moves the fill and the percent of a download that shows, and leaves a hidden pill hidden.
    func progress(_ share: Double) {
        guard panel.isVisible, panel.alphaValue > 0.5, !fill.isHidden else { return }
        note.stringValue = Self.downloadWords(share)
        lay(fill: share)
    }

    private static func downloadWords(_ share: Double) -> String {
        "Downloading \(Int(share * 100))%"
    }

    private func lay(fill share: Double) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = CGRect(x: 0, y: 0, width: ground.bounds.width * share, height: ground.bounds.height)
        CATransaction.commit()
    }

    private func line(_ text: String, share: Double?, for time: TimeInterval) {
        stopMotion()
        undoLabel.isHidden = true
        fill.removeAnimation(forKey: "drain")
        fill.removeAnimation(forKey: "fade")
        fill.opacity = 1
        fill.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        bars.rest()
        bars.isHidden = true
        close.isHidden = true
        done.isHidden = true
        transcribing.rest()
        transcribing.isHidden = true
        note.stringValue = text
        note.isHidden = false
        note.stringValue = share.map(Self.downloadWords) ?? text
        let width = long
        let area = Self.area(at: CGPoint(x: panel.frame.midX, y: panel.frame.midY))
        let centre = CGPoint(x: panel.frame.midX, y: panel.frame.midY)
        var frame = CGRect(x: centre.x - width / 2, y: centre.y - short / 2, width: width, height: short)
        if place.edge == .left { frame.origin.x = area.minX + PillPlace.gap }
        if place.edge == .right { frame.origin.x = area.maxX - width - PillPlace.gap }
        apply(frame, turn: 0)
        note.frame = CGRect(x: 10, y: (short - 16) / 2, width: width - 20, height: 16)
        fill.isHidden = share == nil
        lay(fill: share ?? 0)
        show(keeping: true)
        noteTimer?.invalidate()
        noteTimer = Timer.scheduledTimer(withTimeInterval: time, repeats: false) { [weak self] _ in self?.hide() }
    }

    func hide() {
        onClick = nil
        ground.pointsAt = false
        noteTimer?.invalidate()
        bars.rest()
        transcribing.rest()
        showing += 1
        let hiding = showing
        guard panel.isVisible else { return }
        bloom(opening: false) { [weak self] in
            guard let self, showing == hiding else { return }
            panel.orderOut(nil)
        }
    }

    private func show(keeping: Bool = false) {
        let isOut = !panel.isVisible || panel.alphaValue < 0.5
        if !keeping, isOut { rest() }
        showing += 1
        panel.orderFrontRegardless()
        if isOut {
            bloom(opening: true)
        } else {
            panel.alphaValue = 1
        }
    }

    /// Grows the pill out of a dot at the middle of its frame, or draws it back into one, with no bounce. Its buttons, dots and
    /// words fade in as it grows and out as it shrinks, and the window's frame clips them all the way.
    private func bloom(opening: Bool, then end: (() -> Void)? = nil) {
        stopMotion()
        bloomTimer?.invalidate()
        let whole = opening ? panel.frame : (bloomWhole ?? panel.frame)
        bloomWhole = whole
        let dot = CGRect(x: whole.midX - short / 2, y: whole.midY - short / 2, width: short, height: short)
        let start = CACurrentMediaTime()
        let time: CFTimeInterval = opening ? 0.26 : 0.18
        let turn = self.turn
        let timer = Timer(timeInterval: 1 / 120, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            let share = min((CACurrentMediaTime() - start) / time, 1)
            let size = opening ? 1 - pow(1 - share, 3) : 1 - share * share
            let frame = CGRect(
                x: dot.minX + (whole.minX - dot.minX) * size, y: dot.minY + (whole.minY - dot.minY) * size,
                width: dot.width + (whole.width - dot.width) * size, height: dot.height + (whole.height - dot.height) * size
            )
            apply(frame, turn: turn)
            let bounds = ground.bounds
            bars.frame = CGRect(x: (bounds.width - whole.width) / 2, y: (bounds.height - whole.height) / 2, width: whole.width, height: whole.height)
            bars.turn = turn
            let fade = size * size
            for part in [bars, transcribing, note] as [NSView] { part.alphaValue = fade }
            close.alphaValue *= fade
            done.alphaValue *= fade
            panel.alphaValue = min(1, size * 3)
            guard share >= 1 else { return }
            timer.invalidate()
            bloomTimer = nil
            if opening { bloomWhole = nil }
            end?()
        }
        bloomTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        timer.fire()
    }

    /// Puts the pill at its place on the screen under the pointer, with no motion.
    private func rest() {
        stopMotion()
        let frame = place.frame(long: long, short: short, in: Self.area(at: NSEvent.mouseLocation))
        apply(frame, turn: place.edge.isUpright ? 1 : 0)
    }

    /// Slides the pill to the edge nearest the pointer. A change between a row and a column turns it in one motion.
    private func drag(to pointer: CGPoint) {
        let area = Self.area(at: pointer)
        place = PillPlace(pointer: pointer, in: area)
        let frame = place.frame(long: long, short: short, in: area)
        let next: CGFloat = place.edge.isUpright ? 1 : 0
        if motion == nil, next == turn {
            apply(frame, turn: turn)
            return
        }
        if motion == nil || next != goal.turn {
            motion = (panel.frame, turn, CACurrentMediaTime())
        }
        goal = (frame, next)
        guard motionTimer == nil else { return }
        motionTimer = Timer.scheduledTimer(withTimeInterval: 1 / 120, repeats: true) { [weak self] _ in self?.step() }
        RunLoop.main.add(motionTimer!, forMode: .common)
    }

    private func step() {
        guard let motion else { return stopMotion() }
        let share = min((CACurrentMediaTime() - motion.start) / motionTime, 1)
        let eased = 1 - pow(1 - share, 3)
        let turn = motion.turn + (goal.turn - motion.turn) * eased
        let centre = CGPoint(
            x: motion.frame.midX + (goal.frame.midX - motion.frame.midX) * eased,
            y: motion.frame.midY + (goal.frame.midY - motion.frame.midY) * eased
        )
        let size = shape(at: turn)
        apply(CGRect(x: centre.x - size.width / 2, y: centre.y - size.height / 2, width: size.width, height: size.height), turn: turn)
        if share >= 1 { stopMotion() }
    }

    /// The size of the pill as it turns: the row draws in to a circle by 0.5, and the column grows out of it.
    private func shape(at turn: CGFloat) -> CGSize {
        turn <= 0.5
            ? CGSize(width: long - (long - short) * turn * 2, height: short)
            : CGSize(width: short, height: short + (long - short) * (turn - 0.5) * 2)
    }

    private func stopMotion() {
        motionTimer?.invalidate()
        motionTimer = nil
        motion = nil
    }

    /// Sets the frame and lays out the buttons at the ends of its long side and the dots between, for a turn from 0, a
    /// row, to 1, a column. The buttons fade out as the pill draws in to a circle, and back as it grows.
    private func apply(_ frame: CGRect, turn: CGFloat) {
        self.turn = turn
        panel.setFrame(frame, display: false)
        let bounds = ground.bounds
        let edge = short / 2
        let isColumn = turn > 0.5
        let first = isColumn ? CGPoint(x: bounds.midX, y: bounds.maxY - edge) : CGPoint(x: edge, y: bounds.midY)
        let last = isColumn ? CGPoint(x: bounds.midX, y: edge) : CGPoint(x: bounds.maxX - edge, y: bounds.midY)
        close.frame.origin = CGPoint(x: first.x - close.frame.width / 2, y: first.y - close.frame.height / 2)
        done.frame.origin = CGPoint(x: last.x - done.frame.width / 2, y: last.y - done.frame.height / 2)
        let fullness = pow(abs(1 - 2 * turn), 2)
        close.alphaValue = fullness
        done.alphaValue = fullness
        bars.frame = bounds
        bars.turn = turn
        transcribing.frame = bounds
        transcribing.lay(column: turn > 0.5)
        panel.display()
    }

    /// Keeps the place where the person let the pill go.
    private func keep() {
        try? place.text.write(to: file, atomically: true, encoding: .utf8)
    }

    /// The screen under a point, below its menu bar.
    private static func area(at point: CGPoint) -> CGRect {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
        var area = screen.frame
        area.size.height = screen.visibleFrame.maxY - area.minY
        return area
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

/// One dictation at a time: the key starts it, and the key or ✓ stops it and shows Transcribing until Whisper reads the
/// words, then hides the pill and pastes them. Escape or ✕ discards it. Silence never stops it.
final class Dictation {
    enum Phase { case idle, recording, discarded, working }

    private(set) var phase = Phase.idle
    private let recording = Recording()
    private let whisper: Whisper
    private let clipboard = Clipboard()
    private let history: History
    private var pill: Pill!
    private var escape: EscapeKey!
    private let shortest = 0.3
    private let model: URL
    private var download: ModelDownload?
    /// The sound of a discarded dictation, kept for `undoTime` so that the person can bring it back.
    private var kept: [Float] = []
    private var undoTimer: Timer?
    private let undoTime: TimeInterval = 5

    init(model: String, folder: URL) {
        self.model = URL(fileURLWithPath: model)
        whisper = Whisper(model: model, folder: folder)
        history = History(file: folder.appendingPathComponent("history"))
        pill = Pill(folder: folder, discard: { [weak self] in self?.discard() }, finish: { [weak self] in self?.finish() })
        escape = EscapeKey { [weak self] in
            guard let self else { return }
            phase == .discarded ? drop() : discard()
        }
    }

    /// A press of the person's key.
    func toggle() {
        switch phase {
        case .idle: start()
        case .recording: finish()
        case .discarded: resume()
        case .working: break
        }
    }

    func stop() {
        whisper.stop()
    }

    private func start() {
        guard FileManager.default.fileExists(atPath: model.path) else { return fetch() }
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async { if granted { self.start() } }
            }
            return
        case .authorized: break
        default:
            pill.say("Microphone is off")
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            return
        }
        do {
            try recording.start { [weak self] level in self?.pill.bars.take(level) }
        } catch {
            pill.say("No microphone")
            return
        }
        phase = .recording
        whisper.start()
        escape.hold()
        pill.record()
    }

    /// Downloads the model, or shows how far the download has come. The percent goes to a file that the spot's sheet
    /// reads, and the pill says when Whisper is ready.
    func fetch() {
        if let download { return pill.download(download.share) }
        guard !FileManager.default.fileExists(atPath: model.path) else { return pill.say("Dictate is ready") }
        let percent = model.deletingLastPathComponent().appendingPathComponent("download")
        var shown = -1
        download = ModelDownload(to: model, progress: { [weak self] share in
            self?.pill.progress(share)
            if Int(share * 100) != shown {
                shown = Int(share * 100)
                try? String(shown).write(to: percent, atomically: true, encoding: .utf8)
            }
        }, end: { [weak self] landed in
            try? FileManager.default.removeItem(at: percent)
            self?.download = nil
            if landed {
                self?.pill.say("Dictate is ready", for: 5)
            } else {
                self?.pill.say("Download failed", for: 5)
            }
        })
        let start = download?.share ?? 0
        try? String(Int(start * 100)).write(to: percent, atomically: true, encoding: .utf8)
        pill.download(start)
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
                pill.say("Try again")
                return
            }
            let text = Transcript(whisper: heard).text
            guard !text.isEmpty else {
                pill.say("No words heard")
                return
            }
            history.add(text)
            pill.hide()
            guard let fault = clipboard.paste(text) else { return }
            if fault.contains("Accessibility") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            } else {
                pill.say("Press ⌘V to paste")
            }
        }
    }
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
case "fetch":
    guard arguments.count == 4, let source = URL(string: arguments[2]) else { exit(2) }
    var fetching: ModelDownload?
    var startBytes: Int64 = 0
    fetching = ModelDownload(from: source, to: URL(fileURLWithPath: arguments[3]), progress: { _ in }, end: { landed in
        print("from \(startBytes)")
        print(landed ? "landed" : "failed")
        _ = fetching
        exit(landed ? 0 : 1)
    })
    startBytes = fetching?.have ?? 0
    RunLoop.main.run()
case "remember":
    guard arguments.count == 5, let time = Double(arguments[3]) else { exit(2) }
    History(file: URL(fileURLWithPath: arguments[2])).add(arguments[4], at: Date(timeIntervalSince1970: time))
case "wave":
    let samples = arguments.dropFirst(2).compactMap(Float.init)
    FileHandle.standardOutput.write(Wave(samples: samples, rate: Recording.rate).data)
case "preview":
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let folder = URL(fileURLWithPath: arguments[0]).deletingLastPathComponent()
    let pill = Pill(folder: folder, discard: { exit(0) }, finish: { exit(0) })
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
    signal(SIGUSR2, SIG_IGN)
    let fetch = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
    fetch.setEventHandler { dictation.fetch() }
    fetch.resume()
    let end = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
    end.setEventHandler { dictation.stop(); exit(0) }
    end.resume()
    let watch = DispatchSource.makeProcessSource(identifier: parent, eventMask: .exit, queue: .main)
    watch.setEventHandler { dictation.stop(); exit(0) }
    watch.resume()
    if kill(parent, 0) != 0 { dictation.stop(); exit(0) }
    if arguments.count > 4, arguments[4] == "start" { DispatchQueue.main.async { dictation.toggle() } }
    if arguments.count > 4, arguments[4] == "fetch" { DispatchQueue.main.async { dictation.fetch() } }
    app.run()
default:
    exit(2)
}
