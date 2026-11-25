import Foundation

public enum MacAccess: String, CaseIterable, Sendable {
    case accessibility, automation, screen, calendars, reminders, camera, microphone, input, helper

    public init?(pane: URL) {
        let panes: [String: MacAccess] = [
            "Privacy_Accessibility": .accessibility, "Privacy_Automation": .automation, "Privacy_ScreenCapture": .screen,
            "Privacy_Calendars": .calendars, "Privacy_Reminders": .reminders, "Privacy_Camera": .camera,
            "Privacy_Microphone": .microphone, "Privacy_ListenEvent": .input, "com.apple.LoginItems-Settings.extension": .helper
        ]
        let text = pane.absoluteString
        guard text.hasPrefix("x-apple.systempreferences:"), let found = panes.first(where: { text.hasSuffix($0.key) })?.value else { return nil }
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
}
