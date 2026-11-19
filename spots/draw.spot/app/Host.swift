import Foundation

/// Openspot at the other end of stdin and stdout. It writes each call as a block of lines and a blank line, and takes
/// each frame that Draw prints.
final class Host: @unchecked Sendable {
    private let lock = NSLock()
    private let output: FileHandle
    private let command: @Sendable ([String]) -> Void

    /// The host that reads what Draw prints from `output`, and that hands the words of each call of `openspot` to
    /// `command`.
    init(output: FileHandle = .standardOutput, command: @escaping @Sendable ([String]) -> Void = Host.openspot) {
        self.output = output
        self.command = command
    }

    /// Runs `openspot` with these words, such as `toast Saved`, for the call that Draw answers.
    func call(_ words: [String]) {
        command(words)
    }

    /// Runs the `openspot` command of the Mac with these words for the call that Draw answers, and waits for its end.
    static func openspot(_ words: [String]) {
        let argv = (["/usr/bin/env", "openspot"] + words).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        var actions: posix_spawn_file_actions_t?
        posix_spawn_file_actions_init(&actions)
        defer { posix_spawn_file_actions_destroy(&actions) }
        posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0)
        posix_spawn_file_actions_addopen(&actions, STDOUT_FILENO, "/dev/null", O_WRONLY, 0)
        var child: pid_t = 0
        guard posix_spawn(&child, argv[0], &actions, nil, argv, environ) == 0 else { return }
        var status: Int32 = 0
        while waitpid(child, &status, 0) < 0, errno == EINTR {}
    }

    /// Reads the blocks of stdin on a thread of its own and hands each call to `take` on the main thread. It hands nil
    /// when stdin closes, which is how Openspot says that it no longer wants Draw.
    func listen(_ take: @escaping @MainActor @Sendable (Call?) -> Void) {
        let reading = Thread {
            var lines: [String] = []
            while let line = readLine(strippingNewline: true) {
                if !line.isEmpty {
                    lines.append(line)
                    continue
                }
                let call = Call(lines: lines)
                lines = []
                if let call { DispatchQueue.main.async { take(call) } }
            }
            DispatchQueue.main.async { take(nil) }
        }
        reading.name = "draw.host"
        reading.start()
    }

    /// Prints one frame.
    func send(_ frame: String) {
        lock.withLock {
            output.write(Data((frame + (frame.hasSuffix("\n") ? "" : "\n") + "---\n").utf8))
        }
    }
}
