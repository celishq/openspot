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
}
