import Foundation
import OpenspotCore

actor Tally {
    private var count = 0
    private(set) var isHeld = false

    func hold(_ held: Bool) {
        isHeld = held
    }

    func next() -> Int {
        count += 1
        return count
    }
}

func note(_ line: String, in name: String) {
    guard let folder = ProcessInfo.processInfo.environment["STANDIN_FOLDER"] else { return }
    let descriptor = open(folder + "/" + name, O_WRONLY | O_CREAT | O_APPEND, 0o600)
    guard descriptor >= 0 else { return }
    let bytes = Array((line + "\n").utf8)
    _ = write(descriptor, bytes, bytes.count)
    close(descriptor)
}

@Sendable func answer(_ request: Data, tally: Tally) async -> Data {
    let text = String(decoding: request, as: UTF8.self)
    if text == "die" { exit(3) }
    if text == "empty" { return Data() }
    if text.hasPrefix("echo ") { return Data(text.dropFirst(5).utf8) }
    if text == "slow" {
        note(text, in: "heard")
        try? await Task.sleep(for: .seconds(2))
    }
    if text == "hold" || text == "free" { await tally.hold(text == "hold") }
    return Data("pid=\(getpid())\ncount=\(await tally.next())\n".utf8)
}

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
        capability.serve(isBusy: {
            let isHeld = await tally.isHeld
            note(isHeld ? "held" : "free", in: "idle")
            return isHeld
        }) { await answer($0, tally: tally) }
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
