#!/usr/bin/env swift
// title=Agents
// icon=sparkles
// detail=Claude Code and Codex at work
// on=panel.open
// on=sheet.open
// on=clock.5
// offers=card
// offers=menubar
// view=card.swift
// source=agents
//
// field=claude
// title=Claude command
//
// field=codex
// title=Codex command

// Reads the sessions that Claude Code and Codex keep on disk: what each was last asked, whether it waits for you, and how
// full its context is. Claude's usage limit comes from `claude -p /usage`, which takes a few seconds, so the spot keeps
// it in its data folder for five minutes and reads it again after it has shown the rest. Codex writes its limit in its
// session files. Each command in Settings is run in your own shell, so an alias such as `claude-personal` works, and
// its config folder comes from the alias, such as `CLAUDE_CONFIG_DIR=~/.claude-personal`.
import Foundation

let environment = ProcessInfo.processInfo.environment
let home = FileManager.default.homeDirectoryForCurrentUser.path
let data = URL(fileURLWithPath: environment["OPENSPOT_DATA"] ?? FileManager.default.currentDirectoryPath)
let shell = environment["SHELL"] ?? "/bin/zsh"
let claude = Command(text: setting("CLAUDE") ?? "claude")
let codex = Command(text: setting("CODEX") ?? "codex")
let arguments = Array(CommandLine.arguments.dropFirst())

/// The value of a setting of the spot, or nil when it is not set.
func setting(_ key: String) -> String? {
    let value = environment["OPENSPOT_SETTING_\(key)"]?.trimmingCharacters(in: .whitespaces)
    return value?.isEmpty == false ? value : nil
}

/// Runs a program and gives what it printed, or nil when it failed or took longer than the limit.
func run(_ path: String, _ arguments: [String], in folder: URL? = nil, limit: TimeInterval = 5) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    process.currentDirectoryURL = folder
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    process.standardInput = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return nil }
    let timer = DispatchWorkItem { process.terminate() }
    DispatchQueue.global().asyncAfter(deadline: .now() + limit, execute: timer)
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    timer.cancel()
    return process.terminationStatus == 0 ? text : nil
}

/// Runs the `openspot` command and tells whether it worked. It starts with posix_spawn, which keeps file descriptor 11
/// open, since that is how Openspot knows which spot calls it, and `Process` closes it.
func openspot(_ arguments: [String]) -> Bool {
    var pid: pid_t = 0
    var actions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&actions)
    posix_spawn_file_actions_addopen(&actions, 0, "/dev/null", O_RDONLY, 0)
    posix_spawn_file_actions_addopen(&actions, 1, "/dev/null", O_WRONLY, 0)
    defer { posix_spawn_file_actions_destroy(&actions) }
    let words = ["openspot"] + arguments
    var argv = words.map { strdup($0) } + [nil]
    defer { argv.forEach { free($0) } }
    guard posix_spawnp(&pid, "openspot", &actions, nil, &argv, environ) == 0 else { return false }
    var status: Int32 = 0
    waitpid(pid, &status, 0)
    return status == 0
}

/// Runs a command line in the person's interactive shell, which knows their aliases.
func runInShell(_ line: String, in folder: URL? = nil, limit: TimeInterval = 5) -> String? {
    run(shell, ["-ic", line], in: folder, limit: limit)
}

/// The name of a file in the data folder that belongs to a command.
func kept(_ name: String, _ command: Command) -> URL {
    data.appendingPathComponent("\(name)-\(String(command.text.map { $0.isLetter || $0.isNumber ? $0 : "_" })).txt")
}

/// The config folder of a command: the one its alias sets, or the default. The answer is kept until the setting changes.
func folder(of command: Command, variable: String, fallback: String) -> URL {
    let file = kept("folder", command)
    if let known = try? String(contentsOf: file, encoding: .utf8) { return URL(fileURLWithPath: known) }
    let name = command.text.split(separator: " ").first.map(String.init) ?? command.text
    let alias = runInShell("alias \(name)") ?? ""
    let found = command.folder(alias: alias, variable: variable, home: home) ?? environment[variable] ?? fallback
    try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
    try? found.write(to: file, atomically: true, encoding: .utf8)
    return URL(fileURLWithPath: found)
}

/// The Claude limit kept from the last `/usage`, and whether it is older than five minutes.
func keptClaudeLimit() -> (Limit?, stale: Bool) {
    let file = kept("usage", claude)
    let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    let text = (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    return (Limit(claudeUsage: text), Date().timeIntervalSince(date) > 300)
}

/// Asks Claude Code for its usage, and keeps the answer.
func readClaudeLimit() {
    let file = kept("usage", claude)
    try? FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
    let text = runInShell("\(claude.text) -p /usage --no-session-persistence", in: data, limit: 30) ?? ""
    try? text.write(to: file, atomically: true, encoding: .utf8)
}

/// Each running Codex, found by its process, with the folder it works in.
func runningCodex() -> [Running] {
    let list = run("/bin/ps", ["-axo", "pid=,tty=,args="]) ?? ""
    return list.split(separator: "\n").compactMap { line -> Running? in
        let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
        guard parts.count == 3, parts[1] != "??", let pid = Int32(parts[0]) else { return nil }
        let words = parts[2].split(separator: " ")
        let program = words.first.map { ($0 as NSString).lastPathComponent } ?? ""
        let isCodex = program == "codex" || (program == "node" && words.dropFirst().first?.contains("codex") == true)
        guard isCodex, let cwd = run("/usr/sbin/lsof", ["-a", "-p", "\(pid)", "-d", "cwd", "-Fn"])?
            .split(separator: "\n").first(where: { $0.hasPrefix("n") })?.dropFirst() else { return nil }
        return Running(pid: pid, folder: String(cwd))
    }
}

/// Whether macOS shows the dark appearance.
func isDark() -> Bool {
    run("/usr/bin/defaults", ["read", "-g", "AppleInterfaceStyle"])?.contains("Dark") == true
}

/// The frame of every session and limit, with the actions of the spot.
func board(claudeLimit: Limit?) -> String {
    let claudeFolder = ClaudeFolder(url: folder(of: claude, variable: "CLAUDE_CONFIG_DIR", fallback: "\(home)/.claude"))
    let codexFolder = CodexFolder(url: folder(of: codex, variable: "CODEX_HOME", fallback: "\(home)/.codex"))
    let sessions = claudeFolder.sessions { kill($0, 0) == 0 || errno == EPERM } + codexFolder.sessions(running: runningCodex())
    let limits = [claudeLimit, codexFolder.limit()].compactMap { $0 }
    return Board(sessions: sessions, limits: limits, logos: Logo.files(in: data.appendingPathComponent("logos"), dark: isDark())).frame + """

        button=new-claude
        title=New Claude session
        scope=spot
        close=true

        button=new-codex
        title=New Codex session
        scope=spot
        close=true

        """
}

/// The tty of a process, such as `/dev/ttys012`.
func tty(of pid: Int32) -> String? {
    guard let name = run("/bin/ps", ["-o", "tty=", "-p", "\(pid)"])?.trimmingCharacters(in: .whitespacesAndNewlines),
          !name.isEmpty, name != "??" else { return nil }
    return "/dev/\(name)"
}

/// The path of the app that a process runs in, such as a terminal, found by walking up its parents.
func app(of pid: Int32) -> String? {
    var current = pid
    for _ in 0..<32 {
        guard let line = run("/bin/ps", ["-o", "ppid=,comm=", "-p", "\(current)"])?.trimmingCharacters(in: .whitespacesAndNewlines),
              let space = line.firstIndex(of: " "), let parent = Int32(line[..<space]) else { return nil }
        let command = line[line.index(after: space)...].trimmingCharacters(in: .whitespaces)
        if let end = command.range(of: ".app/") { return String(command[..<end.lowerBound]) + ".app" }
        guard parent > 1 else { return nil }
        current = parent
    }
    return nil
}

/// Brings the terminal of a session to the front, with its tmux pane when it runs in one.
func focus(pid: Int32) {
    var host = pid
    if let tty = tty(of: pid), let panes = run("/usr/bin/env", ["tmux", "list-panes", "-a", "-F", "#{pane_tty} #{pane_id}"]),
       let pane = panes.split(separator: "\n").first(where: { $0.hasPrefix(tty + " ") })?.split(separator: " ").last {
        _ = run("/usr/bin/env", ["tmux", "select-window", "-t", String(pane)])
        _ = run("/usr/bin/env", ["tmux", "select-pane", "-t", String(pane)])
        if let client = run("/usr/bin/env", ["tmux", "list-clients", "-F", "#{client_pid}"])?.split(separator: "\n").first, let id = Int32(client) {
            host = id
        }
    }
    if let path = app(of: host) { _ = run("/usr/bin/open", ["-a", path]) }
}

/// Starts a new session of a command: in a new tmux window when tmux runs, or in a new Terminal window.
func start(_ command: Command) {
    if run("/usr/bin/env", ["tmux", "has-session"]) != nil {
        _ = run("/usr/bin/env", ["tmux", "new-window", "-c", home, "\(shell) -ic '\(command.text)'"])
        if let client = run("/usr/bin/env", ["tmux", "list-clients", "-F", "#{client_pid}"])?.split(separator: "\n").first,
           let id = Int32(client), let path = app(of: id) {
            _ = run("/usr/bin/open", ["-a", path])
        }
        return
    }
    let line = command.text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    _ = run("/usr/bin/osascript", ["-e", "tell application \"Terminal\" to do script \"\(line)\"", "-e", "tell application \"Terminal\" to activate"])
}

/// Asks for a command in a form, or keeps the one the form gave.
func change(_ key: String, title: String, current: Command) {
    let input = String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self)
    let given = input.split(separator: "\n").first { $0.hasPrefix("\(key)=") }.map { $0.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces) }
    guard let given, !given.isEmpty else {
        print("title=\(title)\n\nfield=\(key)\ntitle=Command\nvalue=\(current.text)\nplaceholder=\(key)")
        return
    }
    guard openspot(["setting", "set", key, given]) else {
        print("toast=Openspot cannot keep the command.")
        return
    }
    for name in ["folder", "usage"] { try? FileManager.default.removeItem(at: kept(name, Command(text: given))) }
}

switch arguments.first {
case "read":
    let (limit, stale) = keptClaudeLimit()
    print(board(claudeLimit: limit), terminator: "")
    if stale {
        print("---")
        readClaudeLimit()
        print(board(claudeLimit: keptClaudeLimit().0), terminator: "")
    }
case "open":
    if let row = arguments.dropFirst().first, let pid = row.split(separator: "/").last.flatMap({ Int32($0) }) { focus(pid: pid) }
case "new-claude":
    start(claude)
case "new-codex":
    start(codex)
case "claude":
    change("claude", title: "Claude command", current: claude)
case "codex":
    change("codex", title: "Codex command", current: codex)
default:
    break
}
