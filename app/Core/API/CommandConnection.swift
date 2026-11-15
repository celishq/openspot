import Foundation

final class CommandConnection: @unchecked Sendable {
    struct Limits: Sendable {
        var caller: TimeInterval = 5
        var reader: TimeInterval = 300
        var line = 8 << 20
        var output = 64 << 20
    }

    private static let chunk = 65_536
    private static let lineEnd = UInt8(ascii: "\n")

    private let descriptor: Int32
    private let limits: Limits
    private let queue = DispatchQueue(label: "dev.openspot.api.call")
    private let reads: any DispatchSourceRead
    private var writes: (any DispatchSourceWrite)?
    private var sources = 1
    private var incoming = Data()
    private var outgoing = Data()
    private var sent = 0
    private var stall: DispatchWorkItem?
    private var drains: [CheckedContinuation<Bool, Never>] = []
    private var asked: (@Sendable (CommandConnection, Data) -> Void)?
    private var closed: (@Sendable () -> Void)?
    private var isClosed = false
    private var isEnding = false
    private let lock = NSLock()
    private var pull: Task<String, Never>?
    private let input: AsyncStream<String>
    private let inputEnd: AsyncStream<String>.Continuation

    init(descriptor: Int32, limits: Limits, asked: @escaping @Sendable (CommandConnection, Data) -> Void) {
        self.descriptor = descriptor
        self.limits = limits
        self.asked = asked
        (input, inputEnd) = AsyncStream.makeStream(of: String.self)
        _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
        var on: Int32 = 1
        setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        reads = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        reads.setEventHandler { [self] in receive() }
        reads.setCancelHandler { [self] in release() }
        queue.asyncAfter(deadline: .now() + limits.caller) { [weak self] in self?.askWithWhatCame() }
        reads.resume()
    }

    func listen(closed: @escaping @Sendable () -> Void) {
        queue.async { [self] in
            if isClosed { closed() } else { self.closed = closed }
        }
    }

    func stdin() async -> String {
        let task = lock.withLock {
            if let pull { return pull }
            let task = Task { [self] in
                notify("stdin", text: nil)
                var text = ""
                for await chunk in input { text += chunk }
                return text
            }
            pull = task
            return task
        }
        return await task.value
    }

    func notify(_ method: String, text: String?) {
        var object: [String: Any] = ["jsonrpc": "2.0", "method": method]
        if let text { object["params"] = ["text": text] }
        send(object)
    }

    func deliver(_ method: String, text: String) async {
        var rest = Substring(text)
        while !rest.isEmpty {
            let end = rest.unicodeScalars.index(rest.startIndex, offsetBy: Self.chunk, limitedBy: rest.endIndex) ?? rest.endIndex
            notify(method, text: String(rest[..<end]))
            rest = rest[end...]
            guard await isDrained() else { return }
        }
    }

    private func isDrained() async -> Bool {
        await withCheckedContinuation { drain in
            queue.async { [self] in
                if isClosed || sent == outgoing.count { drain.resume(returning: !isClosed) } else { drains.append(drain) }
            }
        }
    }

    private func tell(isDrained: Bool) {
        let waiting = drains
        drains = []
        for drain in waiting { drain.resume(returning: isDrained) }
    }

    func end(_ reply: [String: Any]) {
        send(reply)
        queue.async { [self] in
            isEnding = true
            if sent == outgoing.count { close() }
        }
    }

    private func send(_ object: [String: Any]) {
        guard let encoded = try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes]) else { return }
        queue.async { [self] in
            guard !isClosed else { return }
            guard outgoing.count - sent <= limits.output else { return close() }
            outgoing.append(encoded)
            outgoing.append(Self.lineEnd)
            flush()
        }
    }

    private func flush() {
        var hasMoved = false
        while !isClosed, sent < outgoing.count {
            let count = outgoing.withUnsafeBytes { write(descriptor, $0.baseAddress! + sent, $0.count - sent) }
            if count > 0 {
                sent += count
                hasMoved = true
            } else if errno == EAGAIN {
                dropWhatWasSent()
                return waitForTheReader(hasMoved: hasMoved)
            } else if errno != EINTR {
                return close()
            }
        }
        guard !isClosed else { return }
        outgoing = Data()
        sent = 0
        tell(isDrained: true)
        stall?.cancel()
        stall = nil
        writes?.cancel()
        writes = nil
        if isEnding { close() }
    }

    private func dropWhatWasSent() {
        guard sent >= Self.chunk, sent >= outgoing.count - sent else { return }
        outgoing = Data(outgoing[sent...])
        sent = 0
    }

    private func waitForTheReader(hasMoved: Bool) {
        if writes == nil {
            let source = DispatchSource.makeWriteSource(fileDescriptor: descriptor, queue: queue)
            source.setEventHandler { [self] in flush() }
            source.setCancelHandler { [self] in release() }
            sources += 1
            writes = source
            source.resume()
        }
        guard hasMoved || stall == nil else { return }
        stall?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.close() }
        stall = item
        queue.asyncAfter(deadline: .now() + limits.reader, execute: item)
    }

    private func receive() {
        var bytes = [UInt8](repeating: 0, count: Self.chunk)
        while !isClosed {
            let count = recv(descriptor, &bytes, bytes.count, 0)
            if count > 0 {
                incoming.append(contentsOf: bytes[..<count])
                takeLines()
                if incoming.count > limits.line { close() }
            } else if count == 0 || (errno != EAGAIN && errno != EINTR) {
                close()
            } else if errno == EAGAIN {
                return
            }
        }
    }

    private func takeLines() {
        while !isClosed, let end = incoming.firstIndex(of: Self.lineEnd) {
            let line = Data(incoming[incoming.startIndex..<end])
            incoming = Data(incoming[(end + 1)...])
            take(line)
        }
    }

    private func take(_ line: Data) {
        if let asked {
            self.asked = nil
            return asked(self, line)
        }
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any], object["method"] as? String == "stdin" else { return }
        let params = object["params"] as? [String: Any]
        if let text = params?["text"] as? String { inputEnd.yield(text) }
        if params?["end"] as? Bool == true { inputEnd.finish() }
    }

    private func askWithWhatCame() {
        guard !isClosed, asked != nil else { return }
        let line = incoming
        incoming = Data()
        take(line)
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        stall?.cancel()
        stall = nil
        incoming = Data()
        outgoing = Data()
        sent = 0
        asked = nil
        writes?.cancel()
        writes = nil
        reads.cancel()
        inputEnd.finish()
        tell(isDrained: false)
        closed?()
        closed = nil
    }

    private func release() {
        sources -= 1
        if sources == 0 { Darwin.close(descriptor) }
    }
}
