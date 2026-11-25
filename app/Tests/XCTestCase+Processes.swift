import Darwin
import XCTest
@testable import OpenspotCore

extension XCTestCase {
    func children(running program: String) -> [pid_t] {
        let program = URL(fileURLWithPath: program).resolvingSymlinksInPath().path
        var buffer = [UInt8](repeating: 0, count: Int(MAXPATHLEN))
        return Self.children().filter { id in
            let length = proc_pidpath(id, &buffer, UInt32(buffer.count))
            return length > 0 && URL(fileURLWithPath: String(decoding: buffer[..<Int(length)], as: UTF8.self)).resolvingSymlinksInPath().path == program
        }
    }

    func children(matching words: String) -> [pid_t] {
        Self.children().filter { Self.arguments(of: $0).contains(words) }
    }

    func processes(tagged tag: String) async -> [pid_t] {
        let found = (try? await ScriptProcess.output(url: URL(fileURLWithPath: "/usr/bin/pgrep"), arguments: ["-f", tag], limit: 30)) ?? ""
        return found.split(separator: "\n").compactMap { pid_t($0) }
    }

    private static func children() -> [pid_t] {
        var ids = [pid_t](repeating: 0, count: Int(proc_listallpids(nil, 0)) + 64)
        let count = Int(proc_listallpids(&ids, Int32(ids.count * MemoryLayout<pid_t>.size)))
        return ids.prefix(max(count, 0)).filter { id in
            var info = proc_bsdinfo()
            return proc_pidinfo(id, PROC_PIDTBSDINFO, 0, &info, Int32(MemoryLayout<proc_bsdinfo>.size)) > 0 && info.pbi_ppid == getpid()
        }
    }

    private static func arguments(of id: pid_t) -> String {
        var name = [CTL_KERN, KERN_PROCARGS2, id]
        var size = 0
        guard sysctl(&name, 3, nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return "" }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctl(&name, 3, &bytes, &size, nil, 0) == 0 else { return "" }
        let words = bytes[MemoryLayout<Int32>.size..<size].split(separator: 0, omittingEmptySubsequences: true)
        return words.map { String(decoding: $0, as: UTF8.self) }.joined(separator: " ")
    }
}
