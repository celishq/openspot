import Foundation

final class CommandConnection: @unchecked Sendable {
    private let descriptor: Int32
    private let writes = DispatchQueue(label: "dev.openspot.api.write")
    private let lock = NSLock()
    private var buffer: Data
    private var watch: (any DispatchSourceRead)?
    private var pull: Task<String, Never>?
    private let input: AsyncStream<String>
    private let inputEnd: AsyncStream<String>.Continuation
    private var isClosed = false

    init(descriptor: Int32, rest: Data) {
        self.descriptor = descriptor
        buffer = rest
        (input, inputEnd) = AsyncStream.makeStream(of: String.self)
    }

    func listen(closed: @escaping @Sendable () -> Void) {
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: DispatchQueue(label: "dev.openspot.api.call"))
        source.setEventHandler { [self] in
            var bytes = [UInt8](repeating: 0, count: 65_536)
            let count = recv(descriptor, &bytes, bytes.count, MSG_DONTWAIT)
            if count > 0 { return take(Data(bytes[..<count])) }
            guard count == 0 || (errno != EAGAIN && errno != EINTR) else { return }
            source.cancel()
            inputEnd.finish()
            closed()
        }
        source.setCancelHandler { [self] in writes.async { [self] in close() } }
        lock.withLock { watch = source }
        source.resume()
        take(Data())
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

    func end(_ reply: [String: Any]) {
        send(reply)
        let source = lock.withLock { watch }
        if let source {
            source.cancel()
        } else {
            writes.async { [self] in close() }
        }
    }

    private func take(_ data: Data) {
        let lines: [Data] = lock.withLock {
            buffer.append(data)
            var lines: [Data] = []
            while let end = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                lines.append(buffer[buffer.startIndex..<end])
                buffer = Data(buffer[(end + 1)...])
            }
            return lines
        }
        for line in lines {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any], object["method"] as? String == "stdin" else { continue }
            let params = object["params"] as? [String: Any]
            if let text = params?["text"] as? String { inputEnd.yield(text) }
            if params?["end"] as? Bool == true { inputEnd.finish() }
        }
    }

    private func send(_ object: [String: Any]) {
        guard let encoded = try? JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes]) else { return }
        let line = encoded + [UInt8(ascii: "\n")]
        writes.async { [self] in
            guard !isClosed else { return }
            line.withUnsafeBytes { bytes in
                var offset = 0
                while offset < bytes.count {
                    let count = write(descriptor, bytes.baseAddress! + offset, bytes.count - offset)
                    if count > 0 {
                        offset += count
                    } else if errno != EINTR {
                        break
                    }
                }
            }
        }
    }

    private func close() {
        guard !isClosed else { return }
        isClosed = true
        Darwin.close(descriptor)
    }
}
