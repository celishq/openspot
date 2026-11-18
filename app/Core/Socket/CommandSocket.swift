import Foundation

public final class CommandSocket: @unchecked Sendable {
    public static let name = SocketPath.name
    static let unreadableCode = -32700
    static let aloneCode = -32000
    static let strangerCode = -32001
    private static let queueLength: Int32 = 64

    private let path: String
    private let source: any DispatchSourceRead

    public convenience init?(folder: URL, api: CommandAPI) {
        self.init(folder: folder, api: api, limits: CommandConnection.Limits())
    }

    init?(folder: URL, api: CommandAPI, limits: CommandConnection.Limits, peer: @escaping @Sendable (Int32) -> pid_t? = CommandSocket.peer(of:)) {
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
                Self.serve(connection, limits: limits, peer: peer, caller: nil, api)
            }
        }
        source.setCancelHandler { Darwin.close(listener) }
        source.resume()
    }

    public func close() {
        source.cancel()
        unlink(path)
    }

    static func serve(_ connection: Int32, limits: CommandConnection.Limits = CommandConnection.Limits(), peer: @escaping @Sendable (Int32) -> pid_t? = CommandSocket.peer(of:), caller: SpotCaller?, _ api: CommandAPI) {
        _ = CommandConnection(descriptor: connection, limits: limits) { link, line in
            let process = peer(connection)
            DispatchQueue.global().async { Self.answer(line, on: link, from: process, caller: caller, api) }
        }
    }

    private static func answer(_ line: Data, on link: CommandConnection, from peer: pid_t?, caller: SpotCaller?, _ api: CommandAPI) {
        guard let asked = CommandRequest(line: line) else {
            return link.end(fault(unreadableCode, "Openspot cannot read this request.", id: nil))
        }
        guard let peer else {
            return link.end(fault(strangerCode, "Openspot cannot tell which process sent this call.", id: asked.id))
        }
        let request = api.request(asked, from: peer, caller: caller)
        let output = CommandOutput { text, isError in link.notify(isError ? "stderr" : "stdout", text: text) }
        guard let work = api.work(for: request, input: { await link.stdin() }, isSandboxed: SpotCallers.isSandboxedApart(peer), output: output) else {
            return link.end(fault(aloneCode, "Run this call in a process of its own.", id: request.id))
        }
        let stop = CommandStop()
        link.listen { stop.cancel() }
        let task = Task.detached { await work() }
        stop.hold(task)
        Task.detached {
            let answer = await task.value
            await link.deliver("stdout", text: answer.output)
            await link.deliver("stderr", text: answer.errors)
            link.end(["jsonrpc": "2.0", "id": request.id.map { $0 as Any } ?? NSNull(), "result": ["code": answer.code]])
        }
    }

    private static func fault(_ code: Int, _ message: String, id: Int?) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id.map { $0 as Any } ?? NSNull(), "error": ["code": code, "message": message]]
    }

    @Sendable static func peer(of connection: Int32) -> pid_t? {
        var id: pid_t = 0
        var size = socklen_t(MemoryLayout<pid_t>.size)
        return getsockopt(connection, SOL_LOCAL, LOCAL_PEERPID, &id, &size) == 0 && id > 0 ? id : nil
    }
}
