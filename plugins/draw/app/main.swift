import AppKit

/// Holds a lock on a board's file while its window is open, so a second open brings the first window to the front.
private func claim(_ file: URL) -> Bool {
    let handle = open(file.path + ".lock", O_CREAT | O_RDWR, 0o644)
    guard handle >= 0 else { return true }
    return flock(handle, LOCK_EX | LOCK_NB) == 0
}

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
guard claim(file) else {
    DistributedNotificationCenter.default().postNotificationName(Desk.showName, object: file.path, userInfo: nil, deliverImmediately: true)
    exit(0)
}
MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.regular)
    let desk = Desk(file: file)
    app.delegate = desk
    app.run()
}
