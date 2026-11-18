import Foundation

public enum CommandGroup: String, CaseIterable, Sendable {
    case start = "Start here"
    case build = "Build a spot"
    case mac = "Ask the Mac"
    case app = "Run Openspot"
}
