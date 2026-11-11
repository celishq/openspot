import Darwin

/// Starts the program of the app with the same arguments, which does the call itself.
func startApp(_ app: AppBundle) -> Never {
    let program = app.program
    var argv: [UnsafeMutablePointer<CChar>?] = ([program] + CommandLine.arguments.dropFirst()).map { strdup($0) }
    argv.append(nil)
    execv(program, argv)
    fail("openspot cannot start \(program): \(String(cString: strerror(errno))).")
}

func fail(_ line: String) -> Never {
    let bytes = Array((line + "\n").utf8)
    _ = write(STDERR_FILENO, bytes, bytes.count)
    exit(1)
}

/// Connects to the socket of the API in the config folder, or returns -1 when nothing listens there.
func reach(_ config: String) -> Int32 {
    guard let real = realpath(config, nil) else { return -1 }
    let path = Array((String(cString: real) + "/api.socket").utf8)
    free(real)
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    guard path.count < MemoryLayout.size(ofValue: address.sun_path) else { return -1 }
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { return -1 }
    let result = withUnsafePointer(to: address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard result == 0 else {
        close(descriptor)
        return -1
    }
    return descriptor
}

/// The request of this call as one JSON-RPC 2.0 line: its arguments, its working folder and its `OPENSPOT_*` variables.
func request() -> [UInt8] {
    let argv = CommandLine.arguments.dropFirst().map(JSON.quoted).joined(separator: ",")
    var folder = [CChar](repeating: 0, count: Int(PATH_MAX))
    let cwd = getcwd(&folder, folder.count) == nil ? "" : String(decoding: folder.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    var variables: [String] = []
    var entry = environ
    while let pair = entry.pointee {
        let text = String(cString: pair)
        if text.hasPrefix("OPENSPOT_"), let mark = text.firstIndex(of: "=") {
            variables.append(JSON.quoted(String(text[..<mark])) + ":" + JSON.quoted(String(text[text.index(after: mark)...])))
        }
        entry = entry.advanced(by: 1)
    }
    let line = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ask\",\"params\":{\"argv\":[\(argv)],\"cwd\":\(JSON.quoted(cwd)),\"env\":{\(variables.joined(separator: ","))}}}\n"
    return Array(line.utf8)
}

/// Sends the line, with the descriptor of stdin beside its first byte when this process has one.
func deliver(_ line: [UInt8], on socket: Int32) -> Bool {
    let head = MemoryLayout<cmsghdr>.size
    var control = [UInt8](repeating: 0, count: head + MemoryLayout<Int32>.size)
    control.withUnsafeMutableBytes {
        $0.storeBytes(of: cmsghdr(cmsg_len: socklen_t(head + MemoryLayout<Int32>.size), cmsg_level: SOL_SOCKET, cmsg_type: SCM_RIGHTS), as: cmsghdr.self)
        $0.storeBytes(of: STDIN_FILENO, toByteOffset: head, as: Int32.self)
    }
    let hasInput = fcntl(STDIN_FILENO, F_GETFD) != -1
    var offset = line.withUnsafeBytes { bytes in
        control.withUnsafeMutableBytes { space in
            var vector = iovec(iov_base: UnsafeMutableRawPointer(mutating: bytes.baseAddress), iov_len: bytes.count)
            return withUnsafeMutablePointer(to: &vector) { vector in
                var message = msghdr(msg_name: nil, msg_namelen: 0, msg_iov: vector, msg_iovlen: 1, msg_control: hasInput ? space.baseAddress : nil, msg_controllen: hasInput ? socklen_t(space.count) : 0, msg_flags: 0)
                return sendmsg(socket, &message, 0)
            }
        }
    }
    guard offset > 0 else { return false }
    while offset < line.count {
        let count = line.withUnsafeBytes { write(socket, $0.baseAddress! + offset, line.count - offset) }
        if count > 0 {
            offset += count
        } else if errno != EINTR {
            return false
        }
    }
    return true
}

func receive(on socket: Int32) -> [UInt8] {
    var answer: [UInt8] = []
    var buffer = [UInt8](repeating: 0, count: 65_536)
    while true {
        let count = read(socket, &buffer, buffer.count)
        if count > 0 {
            answer += buffer[..<count]
        } else if count == 0 || errno != EINTR {
            return answer
        }
    }
}

func put(_ bytes: [UInt8], to descriptor: Int32) {
    var offset = 0
    while offset < bytes.count {
        let count = bytes.withUnsafeBytes { write(descriptor, $0.baseAddress! + offset, bytes.count - offset) }
        if count > 0 {
            offset += count
        } else if errno != EINTR {
            return
        }
    }
}

guard let app = AppBundle() else { fail("openspot cannot find the path of its own program.") }
let connection = app.config.map(reach) ?? -1
guard connection >= 0, deliver(request(), on: connection) else { startApp(app) }
guard let answer = JSON(receive(on: connection)) else { fail("Openspot stopped before it answered. Run the call again.") }
guard let result = answer["result"] else { startApp(app) }
if case .text(let output)? = result["stdout"] { put(output, to: STDOUT_FILENO) }
if case .text(let errors)? = result["stderr"] { put(errors, to: STDERR_FILENO) }
if case .number(let code)? = result["code"] { exit(Int32(code)) }
exit(1)
