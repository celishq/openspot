import Foundation

/// The socket of the API in the config folder, which answers each `openspot` call while the app runs (S1). It speaks
/// JSON-RPC 2.0 with one JSON object on each line, as the stdio transport of MCP frames it. A call is a request
/// (`CommandRequest`). The app answers with a notification `stdout` or `stderr` for each piece that the call prints, a
/// notification `stdin` once the call reads stdin, and then a result with the `code`, or an error for a call that the API
/// leaves to a process of its own, which the caller then starts. The caller answers `stdin` with notifications `stdin` whose
/// params hold `text`, and then one whose params hold `end`. A caller that closes its connection stops its call (S13).
public final class CommandSocket: @unchecked Sendable {
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

    /// Reads the request on a connection, streams its answer, and closes the connection.
    private static func answer(_ connection: Int32, _ api: CommandAPI) {
        _ = fcntl(connection, F_SETFL, fcntl(connection, F_GETFL) & ~O_NONBLOCK)
        var on: Int32 = 1
        setsockopt(connection, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var time = timeval(tv_sec: callerLimit, tv_usec: 0)
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
        let (line, rest) = receive(connection)
        let link = CommandConnection(descriptor: connection, rest: rest)
        guard let request = CommandRequest(line: line) else {
            return link.end(fault(unreadable, "Openspot cannot read this request.", id: nil))
        }
        let environment = api.environment(of: peer(of: connection), over: request.environment(over: ProcessInfo.processInfo.environment))
        let call = CommandLineCall(arguments: request.arguments, environment: environment).map { api.admit($0, arguments: request.arguments, environment: environment) }
        let output = CommandOutput { text, isError in link.notify(isError ? "stderr" : "stdout", text: text) }
        guard let call, let work = api.work(for: call, input: { await link.stdin() }, environment: environment, isPiped: request.isPiped, output: output) else {
            return link.end(fault(alone, "Run this call in a process of its own.", id: request.id))
        }
        let task = Task.detached { await work() }
        link.listen { task.cancel() }
        Task.detached {
            let answer = await task.value
            output.print(answer.output)
            output.report(answer.errors)
            link.end(["jsonrpc": "2.0", "id": request.id.map { $0 as Any } ?? NSNull(), "result": ["code": answer.code]])
        }
    }

    private static func fault(_ code: Int, _ message: String, id: Int?) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id.map { $0 as Any } ?? NSNull(), "error": ["code": code, "message": message]]
    }

    /// The ID of the process at the other end of a connection, or 0 when the socket does not say.
    private static func peer(of connection: Int32) -> pid_t {
        var id: pid_t = 0
        var size = socklen_t(MemoryLayout<pid_t>.size)
        return getsockopt(connection, SOL_LOCAL, LOCAL_PEERPID, &id, &size) == 0 ? id : 0
    }

    /// Reads up to the end of the first line, and returns that line and the bytes after it.
    private static func receive(_ connection: Int32) -> (Data, Data) {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: chunk)
        while !data.contains(UInt8(ascii: "\n")) {
            let count = read(connection, &buffer, buffer.count)
            if count > 0 {
                data.append(contentsOf: buffer[..<count])
            } else if count == 0 || errno != EINTR {
                break
            }
        }
        guard let end = data.firstIndex(of: UInt8(ascii: "\n")) else { return (data, Data()) }
        return (data[data.startIndex..<end], Data(data[(end + 1)...]))
    }
}
