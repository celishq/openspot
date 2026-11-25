import Foundation

public enum MacAccess: String, CaseIterable, Sendable {
    case accessibility, automation, screen, calendars, reminders, camera, microphone, input, helper

    public var title: String {
        switch self {
        case .accessibility: "Accessibility"
        case .automation: "Automation"
        case .screen: "Screen Recording"
        case .calendars: "Calendars"
        case .reminders: "Reminders"
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .input: "Input Monitoring"
        case .helper: "Keep-awake helper"
        }
    }

    public var place: String {
        switch self {
        case .screen: "Privacy & Security › Screen & System Audio Recording"
        case .helper: "General › Login Items & Extensions"
        default: "Privacy & Security › \(title)"
        }
    }

    public var pane: URL? {
        switch self {
        case .helper: URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")
        default: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(anchor)")
        }
    }

    public var needsRestart: Bool {
        self == .screen
    }

    private var anchor: String {
        switch self {
        case .screen: "ScreenCapture"
        case .input: "ListenEvent"
        default: title
        }
    }
}
