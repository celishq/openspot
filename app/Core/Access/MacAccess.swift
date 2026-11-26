import Foundation

public enum MacAccess: String, CaseIterable, Sendable {
    case accessibility, automation, screen, calendars, reminders, camera, microphone, input, helper

    public init?(pane: URL) {
        guard let found = Self.allCases.first(where: { $0.pane == pane }) else { return nil }
        self = found
    }

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

    public static let about = [
        SettingsFact("Asked once, when you add or update a spot", "plus.app"),
        SettingsFact("Each spot gets only what it declares", "checklist"),
        SettingsFact("A use it didn’t declare is refused", "hand.raised"),
        SettingsFact("Turn a spot off to stop it", "power"),
        SettingsFact("Turn an access off in System Settings to stop every spot", "gearshape")
    ]

    public var purpose: String {
        switch self {
        case .accessibility: "Reads what you select, and types and moves windows in the front app."
        case .automation: "Reads the front tab of a browser and what Finder has selected."
        case .screen: "Takes a picture or a recording of the screen."
        case .calendars: "Reads your events, and adds the ones you ask for."
        case .reminders: "Reads your reminders, and adds and ticks the ones you ask for."
        case .camera: "Films you beside a screen recording that asks for it."
        case .microphone: "Records your voice with a screen recording that asks for it."
        case .input: "Records each key and click with a screen recording that asks for it."
        case .helper: "Keeps the Mac awake with its lid closed."
        }
    }

    public static func names(_ accesses: [MacAccess]) -> String {
        let titles = accesses.map(\.title)
        guard titles.count > 1 else { return titles.first ?? "" }
        return titles.dropLast().joined(separator: ", ") + " and " + titles[titles.count - 1]
    }
}
