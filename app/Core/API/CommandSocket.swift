import Foundation

public final class CommandSocket: @unchecked Sendable {
    public static let name = SocketPath.name
    static let unreadableCode = -32700
    static let aloneCode = -32000
    private static let queueLength: Int32 = 64
    private static let callerLimit = 5
    private static let chunk = 65_536

    private let path: String
    private let source: any DispatchSourceRead

    public init?(folder: URL, api: CommandAPI) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        guard let real = realpath(folder.path, nil) else { return nil }
        path = SocketPath.of(config: String(cString: real))
        free(real)
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8)
        guard bytes.count < MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        if path.hasPrefix(SocketPath.folder + "/") {
            mkdir(SocketPath.folder, 0o700)
            var info = stat()
            guard lstat(SocketPath.folder, &info) == 0, info.st_mode & S_IFMT == S_IFDIR, info.st_uid == getuid(),
                  chmod(SocketPath.folder, 0o700) == 0 else { return nil }
        }
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

    public func close() {
        source.cancel()
        unlink(path)
    }

    private static func answer(_ connection: Int32, _ api: CommandAPI) {
        _ = fcntl(connection, F_SETFL, fcntl(connection, F_GETFL) & ~O_NONBLOCK)
        var on: Int32 = 1
        setsockopt(connection, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var time = timeval(tv_sec: callerLimit, tv_usec: 0)
        setsockopt(connection, SOL_SOCKET, SO_RCVTIMEO, &time, socklen_t(MemoryLayout<timeval>.size))
        let (line, rest) = receive(connection)
        let link = CommandConnection(descriptor: connection, rest: rest)
        guard let request = CommandRequest(line: line) else {
            return link.end(fault(unreadableCode, "Openspot cannot read this request.", id: nil))
        }
        let environment = api.environment(of: peer(of: connection), over: request.environment(over: ProcessInfo.processInfo.environment))
        let call = CommandLineCall(arguments: request.arguments, environment: environment).map { api.admit($0, arguments: request.arguments, environment: environment) }
        let output = CommandOutput { text, isError in link.notify(isError ? "stderr" : "stdout", text: text) }
        guard let call, let work = api.work(for: call, input: { await link.stdin() }, environment: environment, isPiped: request.isPiped, isSandboxed: CallerTokens.isSandboxedApart(peer(of: connection)), output: output) else {
            return link.end(fault(aloneCode, "Run this call in a process of its own.", id: request.id))
        }
        let stop = CommandStop()
        link.listen { stop.cancel() }
        let task = Task.detached { await work() }
        stop.hold(task)
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

    private static func peer(of connection: Int32) -> pid_t {
        var id: pid_t = 0
        var size = socklen_t(MemoryLayout<pid_t>.size)
        return getsockopt(connection, SOL_LOCAL, LOCAL_PEERPID, &id, &size) == 0 ? id : 0
    }

    private static func receive(_ connection: Int32) -> (Data, Data) {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: chunk)
        while true {
            let count = read(connection, &buffer, buffer.count)
            if count > 0 {
                data.append(contentsOf: buffer[..<count])
                if buffer[..<count].contains(UInt8(ascii: "\n")) { break }
            } else if count == 0 || errno != EINTR {
                break
            }
        }
        guard let end = data.firstIndex(of: UInt8(ascii: "\n")) else { return (data, Data()) }
        return (data[data.startIndex..<end], Data(data[(end + 1)...]))
    }
}
