import Darwin

let startWaitSeconds = getenv("OPENSPOT_START_WAIT").flatMap { Double(String(cString: $0)) } ?? 10
nonisolated(unsafe) var connection: Int32 = -1

func runAlone(_ app: AppBundle) -> Never {
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

func startInBackground(_ app: AppBundle, config: String) {
    let bundle = String(app.contents[..<(app.contents.lastIndex(of: "/") ?? app.contents.endIndex)])
    var arguments = access(app.contents + "/Info.plist", F_OK) == 0 ? ["/usr/bin/open", "-g", "-j", bundle] : [app.program]
    if arguments.count > 1, getenv("OPENSPOT_CONFIG") != nil { arguments += ["--env", "OPENSPOT_CONFIG=" + config] }
    var actions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    for descriptor in [STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO] {
        posix_spawn_file_actions_addopen(&actions, descriptor, "/dev/null", descriptor == STDIN_FILENO ? O_RDONLY : O_WRONLY, 0)
    }
    var attributes: posix_spawnattr_t?
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETSID))
    let words = arguments.map { strdup($0) } + [nil]
    defer { words.forEach { free($0) } }
    var started: pid_t = 0
    _ = posix_spawn(&started, arguments[0], &actions, &attributes, words, environ)
}

func reachStarted(_ app: AppBundle, config: String) -> Int32 {
    startInBackground(app, config: config)
    var waited = 0.0
    while waited < startWaitSeconds {
        let reached = reach(config)
        if reached >= 0 { return reached }
        usleep(50_000)
        waited += 0.05
    }
    let seconds = startWaitSeconds == startWaitSeconds.rounded() ? String(Int(startWaitSeconds)) : String(startWaitSeconds)
    fail("Openspot did not start within \(seconds) seconds, so this call did not run. Open Openspot, then run it again.")
}

func reach(_ config: String) -> Int32 {
    guard let real = realpath(config, nil) else { return -1 }
    let path = Array(SocketPath.of(config: String(cString: real)).utf8)
    free(real)
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    guard path.count < MemoryLayout.size(ofValue: address.sun_path) else { return -1 }
    withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: path) }
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else { return -1 }
    var on: Int32 = 1
    setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
    let result = withUnsafePointer(to: address) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
    }
    guard result == 0 else {
        close(descriptor)
        return -1
    }
    return descriptor
}

func request() -> [UInt8] {
    let argv = CommandLine.arguments.dropFirst().map(JSON.quoted).joined(separator: ",")
    var folder = [CChar](repeating: 0, count: Int(PATH_MAX))
    let cwd = getcwd(&folder, folder.count) == nil ? "" : String(decoding: folder.prefix { $0 != 0 }.map(UInt8.init(bitPattern:)), as: UTF8.self)
    var variables: [String] = []
    var entry = environ
    while let pair = entry.pointee {
        let text = String(cString: pair)
        if let mark = text.firstIndex(of: "=") {
            variables.append(JSON.quoted(String(text[..<mark])) + ":" + JSON.quoted(String(text[text.index(after: mark)...])))
        }
        entry = entry.advanced(by: 1)
    }
    var info = stat()
    let isPiped = fstat(STDIN_FILENO, &info) == 0 && (info.st_mode & S_IFMT == S_IFIFO || info.st_mode & S_IFMT == S_IFREG)
    let line = "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ask\",\"params\":{\"argv\":[\(argv)],\"cwd\":\(JSON.quoted(cwd)),\"env\":{\(variables.joined(separator: ","))},\"piped\":\(isPiped)}}\n"
    return Array(line.utf8)
}

func deliver(_ line: [UInt8], on socket: Int32) -> Bool {
    var offset = 0
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
let arguments = Array(CommandLine.arguments.dropFirst())
let isLive = CommandKind.needsApp(arguments)
connection = app.configFolder.map(reach) ?? -1
if connection < 0 {
    guard isLive, let config = app.configFolder else { runAlone(app) }
    connection = reachStarted(app, config: config)
}
signal(SIGINT) { _ in
    close(connection)
    _exit(130)
}
guard deliver(request(), on: connection) else {
    guard !isLive else { fail("Openspot stopped before it took the call. Run the call again.") }
    runAlone(app)
}
var input = InputLink(socket: connection)
var pending: [UInt8] = []
var buffer = [UInt8](repeating: 0, count: 65_536)
while true {
    var watched = [pollfd(fd: connection, events: Int16(POLLIN), revents: 0), pollfd(fd: input.isWanted && !input.hasEnded ? STDIN_FILENO : -1, events: Int16(POLLIN), revents: 0)]
    guard poll(&watched, 2, -1) >= 0 || errno == EINTR else { fail("openspot cannot wait for Openspot: \(String(cString: strerror(errno))).") }
    if watched[1].revents != 0 { input.readOnce() }
    guard watched[0].revents != 0 else { continue }
    let count = read(connection, &buffer, buffer.count)
    if count < 0, errno == EINTR { continue }
    guard count > 0 else { fail("Openspot stopped before it answered. Run the call again.") }
    pending += buffer[..<count]
    while let end = pending.firstIndex(of: UInt8(ascii: "\n")) {
        let line = JSON(Array(pending[..<end]))
        pending.removeFirst(end + 1)
        guard let line else { fail("Openspot stopped before it answered. Run the call again.") }
        if case .text(let method)? = line["method"] {
            let text: [UInt8] = if case .text(let text)? = line["params"]?["text"] { text } else { [] }
            switch String(decoding: method, as: UTF8.self) {
            case "stdout": put(text, to: STDOUT_FILENO)
            case "stderr": put(text, to: STDERR_FILENO)
            case "stdin": input.want()
            default: break
            }
            continue
        }
        guard case .number(let code)? = line["result"]?["code"] else {
            guard !isLive else { fail("Openspot cannot run this call. Run `openspot help` to see each call.") }
            runAlone(app)
        }
        exit(Int32(code))
    }
}
