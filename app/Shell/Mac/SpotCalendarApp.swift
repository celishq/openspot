import Foundation
import OpenspotCore

enum SpotCalendarApp {
    private static let automation = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
    private static let script = [
        "on run argv",
        "set theDay to current date",
        "set day of theDay to 1",
        "set year of theDay to (item 1 of argv) as integer",
        "set month of theDay to (item 2 of argv) as integer",
        "set day of theDay to (item 3 of argv) as integer",
        "set time of theDay to (item 4 of argv) as integer",
        "tell application \"Calendar\"",
        "activate",
        "switch view to day view",
        "view calendar at theDay",
        "end tell",
        "end run"
    ]

    static func show(_ time: Date) throws -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let seconds = (parts.hour ?? 0) * 3600 + (parts.minute ?? 0) * 60
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = script.flatMap { ["-e", $0] } + [parts.year, parts.month, parts.day, seconds].map { String($0 ?? 0) }
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SpotError.failedWithFix(1, "Openspot cannot open Calendar. Allow Openspot to control Calendar in Privacy & Security › Automation, then try again.", automation)
        }
        return ""
    }
}
