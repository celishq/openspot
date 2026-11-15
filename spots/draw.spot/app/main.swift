import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
guard let path = arguments.first else {
    FileHandle.standardError.write("Usage: Draw <board.json>\n".data(using: .utf8)!)
    exit(2)
}
let file = URL(fileURLWithPath: path)
guard FileManager.default.fileExists(atPath: file.path) else {
    FileHandle.standardError.write("Draw cannot find \(file.path).\n".data(using: .utf8)!)
    exit(1)
}
guard let lock = Lock.claim(file.deletingLastPathComponent().appendingPathComponent(".draw")) else {
    DistributedNotificationCenter.default().postNotificationName(Desk.openName, object: file.path, userInfo: nil, deliverImmediately: true)
    exit(0)
}
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let desk = Desk(file: file, lock: lock)
    app.delegate = desk
    app.run()
}
