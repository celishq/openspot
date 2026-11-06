import Foundation
import OpenspotCore

/// The memory of the stand-in helper.
actor Tally {
    private var count = 0

    func next() -> Int {
        count += 1
        return count
    }
}

/// Answers a request: `die` ends the helper with no answer, `slow` waits, `empty` is an empty answer, `echo <text>` gives the
/// text back, and anything else gives the process and how many calls it has answered.
@Sendable func answer(_ request: Data, tally: Tally) async -> Data {
    let text = String(decoding: request, as: UTF8.self)
    if text == "die" { exit(3) }
    if text == "empty" { return Data() }
    if text.hasPrefix("echo ") { return Data(text.dropFirst(5).utf8) }
    if text == "slow" { try? await Task.sleep(for: .seconds(2)) }
    return Data("pid=\(getpid())\ncount=\(await tally.next())\n".utf8)
}

/// A capability for tests, with the idle time and the folder from the environment: `<tool> call <name>` sends stdin as a
/// request and prints the answer, and `<tool> helper <name>` is the helper. No real capability can run on a test Mac.
func run() -> Never {
    let arguments = CommandLine.arguments
    let environment = ProcessInfo.processInfo.environment
    guard arguments.count == 3, let folder = environment["STANDIN_FOLDER"] else { exit(2) }
    let capability = Capability(
        name: arguments[2],
        folder: URL(fileURLWithPath: folder, isDirectory: true),
        idle: environment["STANDIN_IDLE"].flatMap(TimeInterval.init) ?? 30
    )
    if arguments[1] == "helper" {
        let tally = Tally()
        capability.serve { await answer($0, tally: tally) }
    }
    do {
        let result = try capability.call(FileHandle.standardInput.readDataToEndOfFile())
        FileHandle.standardOutput.write(result)
        exit(0)
    } catch {
        FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
        exit(1)
    }
}

run()
