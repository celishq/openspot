import Foundation

/// The socket of the API in the config folder, which answers each `openspot` call while the app runs (S1). A call is a
/// JSON-RPC 2.0 request on one line (`CommandRequest`), with the descriptor of its stdin beside the line as `SCM_RIGHTS`.
/// The answer is one line: a result with `stdout`, `stderr` and `code`, or an error for a call that the API leaves to a
/// process of its own, which the caller then starts. A caller that closes its connection first stops the work of its call
/// (S13).
public final class CommandSocket: @unchecked Sendable {
    private struct Reply: Encodable {
        struct Result: Encodable {
            let stdout: String
            let stderr: String
            let code: Int32
        }

        struct Fault: Encodable {
            let code: Int
            let message: String
        }

        let jsonrpc = "2.0"
        let id: Int?
        var result: Result?
        var error: Fault?
    }

    public static let name = "api.socket"
    /// The JSON-RPC code of a line that is not a request.
    static let unreadable = -32700
    /// The JSON-RPC code of a call that runs in a process of its own.
    static let alone = -32000
    private static let queueLength: Int32 = 64
    private static let callerLimit = 5
    private static let chunk = 65_536

    private let path: String
    private let source: any DispatchSourceRead

    /// Listens at `api.socket` in the folder, in place of a socket that an app left there. Returns nil when it cannot.
    public init?(folder: URL, api: CommandAPI) {
        path = folder.appendingPathComponent(Self.name).path
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        unlink(path)
        let listener = socket(AF_UNIX, SOCK_STREAM, 0)
        guard listener >= 0 else { return nil }
        let bound = withUnsafePointer(to: address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listener, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
        guard bound == 0, chmod(path, 0o600) == 0, listen(listener, Self.queueLength) == 0 else {
            Darwin.close(listener)
            return nil
        }
        _ = fcntl(listener, F_SETFD, FD_CLOEXEC)
        _ = fcntl(listener, F_SETFL, O_NONBLOCK)
        source = DispatchSource.makeReadSource(fileDescriptor: listener, queue: DispatchQueue(label: "dev.openspot.api"))
        source.setEventHandler {
            while case let connection = accept(listener, nil, nil), connection >= 0 {
                _ = fcntl(connection, F_SETFD, FD_CLOEXEC)
                DispatchQueue.global().async { Self.answer(connection, api) }
            }
        }
        source.setCancelHandler { Darwin.close(listener) }
        source.resume()
    }

    /// Stops listening and removes the socket.
    public func close() {
        source.cancel()
        unlink(path)
    }

    /// Reads the request on a connection, answers it, and closes the connection and the stdin that came with it.
    private static func answer(_ connection: Int32, _ api: CommandAPI) {
        _ = fcntl(connection, F_SETFL, fcntl(connection, F_GETFL) & ~O_NONBLOCK)
        var on: Int32 = 1
        setsockopt(connection, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var time = timeval(tv_sec: callerLimit, tv_usec: 0)
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
        let (line, input) = receive(connection)
        guard let request = CommandRequest(line: line) else {
            send(Reply(id: nil, error: .init(code: unreadable, message: "Openspot cannot read this request.")), to: connection, input: input)
            return
        }
        let environment = request.environment(over: ProcessInfo.processInfo.environment)
        guard let call = CommandLineCall(arguments: request.arguments, environment: environment),
              let work = api.work(for: call, input: { await Self.text(of: input) }, environment: environment) else {
            send(Reply(id: request.id, error: .init(code: alone, message: "Run this call in a process of its own.")), to: connection, input: input)
            return
        }
        let task = Task.detached { await work() }
        let watch = DispatchSource.makeReadSource(fileDescriptor: connection, queue: DispatchQueue(label: "dev.openspot.api.call"))
        let ends = DispatchGroup()
        ends.enter()
        ends.enter()
        watch.setEventHandler {
            var byte: UInt8 = 0
            guard recv(connection, &byte, 1, MSG_PEEK | MSG_DONTWAIT) == 0 else { return }
            task.cancel()
            watch.cancel()
        }
        watch.setCancelHandler { ends.leave() }
        watch.resume()
        Task.detached {
            let answer = await task.value
            watch.cancel()
            ends.leave()
            ends.notify(queue: .global()) {
                send(Reply(id: request.id, result: .init(stdout: answer.output, stderr: answer.errors, code: answer.code)), to: connection, input: input)
            }
        }
    }

    /// Reads up to the end of the first line, and the descriptor that came with it, or -1 with none.
    private static func receive(_ connection: Int32) -> (Data, Int32) {
        var line = Data()
        var input: Int32 = -1
        var buffer = [UInt8](repeating: 0, count: chunk)
        var control = [UInt8](repeating: 0, count: 64)
        while !line.contains(UInt8(ascii: "\n")) {
            let count = buffer.withUnsafeMutableBytes { data in
                control.withUnsafeMutableBytes { space in
                    var vector = iovec(iov_base: data.baseAddress, iov_len: data.count)
                    return withUnsafeMutablePointer(to: &vector) { vector in
                        var message = msghdr(msg_name: nil, msg_namelen: 0, msg_iov: vector, msg_iovlen: 1, msg_control: space.baseAddress, msg_controllen: socklen_t(space.count), msg_flags: 0)
                        let count = recvmsg(connection, &message, 0)
                        if count >= 0, input < 0 { input = descriptor(in: UnsafeRawBufferPointer(rebasing: space[..<Int(message.msg_controllen)])) }
                        return count
                    }
                }
            }
            if count > 0 {
                line.append(contentsOf: buffer[..<count])
            } else if count == 0 || errno != EINTR {
                break
            }
        }
        return (line.prefix { $0 != UInt8(ascii: "\n") }, input)
    }

    /// The descriptor of the first `SCM_RIGHTS` message in a control buffer, or -1 with none.
    private static func descriptor(in control: UnsafeRawBufferPointer) -> Int32 {
        let head = MemoryLayout<cmsghdr>.size
        guard control.count >= head + MemoryLayout<Int32>.size else { return -1 }
        let header = control.loadUnaligned(as: cmsghdr.self)
        guard header.cmsg_level == SOL_SOCKET, header.cmsg_type == SCM_RIGHTS else { return -1 }
        let descriptor = control.loadUnaligned(fromByteOffset: head, as: Int32.self)
        _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
        return descriptor
    }

    /// All that the stdin of the caller holds, or nothing when the caller sent none.
    private static func text(of input: Int32) async -> String {
        guard input >= 0 else { return "" }
        var data = Data()
        do {
            for try await byte in FileHandle(fileDescriptor: input, closeOnDealloc: false).bytes { data.append(byte) }
        } catch {
            return String(decoding: data, as: UTF8.self)
        }
        return String(decoding: data, as: UTF8.self)
    }

    private static func send(_ reply: Reply, to connection: Int32, input: Int32) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        var line = (try? encoder.encode(reply)) ?? Data()
        line.append(UInt8(ascii: "\n"))
        line.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = write(connection, bytes.baseAddress! + offset, bytes.count - offset)
                if count > 0 {
                    offset += count
                } else if errno != EINTR {
                    break
                }
            }
        }
        Darwin.close(connection)
        if input >= 0 { Darwin.close(input) }
    }
}
