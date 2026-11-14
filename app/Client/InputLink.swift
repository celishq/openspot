import Darwin

struct InputLink {
    let socket: Int32
    private(set) var isWanted = false
    private(set) var hasEnded = false
    private var rest: [UInt8] = []

    init(socket: Int32) {
        self.socket = socket
    }

    mutating func want() {
        guard !isWanted else { return }
        isWanted = true
        if fcntl(STDIN_FILENO, F_GETFD) == -1 { end() }
    }

    mutating func readOnce() {
        var buffer = [UInt8](repeating: 0, count: 65_536)
        let count = read(STDIN_FILENO, &buffer, buffer.count)
        guard count > 0 else {
            if count < 0, errno == EINTR || errno == EAGAIN { return }
            return end()
        }
        rest += buffer[..<count]
        let whole = Self.wholeLength(rest)
        guard whole > 0 else { return }
        send(text: String(decoding: rest[..<whole], as: UTF8.self))
        rest.removeFirst(whole)
    }

    private mutating func end() {
        if !rest.isEmpty { send(text: String(decoding: rest, as: UTF8.self)) }
        rest = []
        hasEnded = true
        _ = deliver(Array("{\"jsonrpc\":\"2.0\",\"method\":\"stdin\",\"params\":{\"end\":true}}\n".utf8), on: socket)
    }

    private func send(text: String) {
        _ = deliver(Array("{\"jsonrpc\":\"2.0\",\"method\":\"stdin\",\"params\":{\"text\":\(JSON.quoted(text))}}\n".utf8), on: socket)
    }

    private static func wholeLength(_ bytes: [UInt8]) -> Int {
        var start = bytes.count
        while start > 0, bytes.count - start < 4 {
            start -= 1
            let byte = bytes[start]
            guard byte & 0xC0 == 0x80 else {
                let size = byte < 0xC0 ? 1 : byte < 0xE0 ? 2 : byte < 0xF0 ? 3 : 4
                return bytes.count - start >= size ? bytes.count : start
            }
        }
        return bytes.count
    }
}
