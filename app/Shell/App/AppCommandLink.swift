import Foundation
import OpenspotCore

/// The link from `/usr/local/bin/openspot` to the command inside this app.
enum AppCommandLink {
    static let item = CommandLink(
        target: Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/openspot"),
        elevated: { line in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", "on run argv", "-e", "do shell script (item 1 of argv) with administrator privileges", "-e", "end run", line]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { throw PluginError.failed(1, "openspot was not installed in Terminal.") }
        }
    )
}
