import XCTest

final class SocketConnection {
    let descriptor: Int32
    private var buffer = Data()

    init(path: String) {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        descriptor = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
        var time = timeval(tv_sec: 10, tv_usec: 0)
        setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
        let connected = withUnsafePointer(to: address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        XCTAssertEqual(connected, 0)
    }

    func send(_ object: [String: Any]) throws {
        let bytes = Array(try JSONSerialization.data(withJSONObject: object)) + [UInt8(ascii: "\n")]
        XCTAssertEqual(write(descriptor, bytes, bytes.count), bytes.count)
    }

    func send(line: String) {
        let bytes = Array((line + "\n").utf8)
        XCTAssertEqual(write(descriptor, bytes, bytes.count), bytes.count)
    }

    func next() throws -> [String: Any]? {
        var chunk = [UInt8](repeating: 0, count: 4096)
        while !buffer.contains(UInt8(ascii: "\n")) {
            let count = read(descriptor, &chunk, chunk.count)
            guard count > 0 else { return nil }
            buffer.append(contentsOf: chunk[..<count])
        }
        let end = buffer.firstIndex(of: UInt8(ascii: "\n"))!
        let line = buffer[buffer.startIndex..<end]
        buffer = Data(buffer[(end + 1)...])
        return try XCTUnwrap(JSONSerialization.jsonObject(with: line) as? [String: Any])
    }

    func close() {
        Darwin.close(descriptor)
    }

    struct Exchange {
        var stdout = ""
        var stderr = ""
        var reply: [String: Any] = [:]

        var code: Int? {
            (reply["result"] as? [String: Any])?["code"] as? Int
        }
    }

    func exchange(input: [String] = []) throws -> Exchange {
        var exchange = Exchange()
        while let line = try next() {
            let text = (line["params"] as? [String: Any])?["text"] as? String ?? ""
            switch line["method"] as? String {
            case "stdout": exchange.stdout += text
            case "stderr": exchange.stderr += text
            case "stdin":
                for chunk in input { try send(["jsonrpc": "2.0", "method": "stdin", "params": ["text": chunk]]) }
                try send(["jsonrpc": "2.0", "method": "stdin", "params": ["end": true]])
            default:
                exchange.reply = line
                return exchange
            }
        }
        XCTFail("the stream ended with no reply")
        return exchange
    }
}
