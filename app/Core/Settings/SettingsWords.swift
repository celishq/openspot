import Foundation

public enum SettingsWords {
    public static func purpose(of access: MacAccess) -> String {
        switch access {
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

    public static func word(of status: ReadAccess) -> String {
        switch status {
        case .allowed: "Allowed"
        case .denied: "Not allowed"
        case .unasked: "Not asked"
        case .unknown: "Unknown"
        }
    }

    public static func sentence(of status: ReadAccess) -> String {
        switch status {
        case .allowed: "macOS gives it to Openspot."
        case .denied: "macOS doesn’t give it to Openspot. Allow… opens its switch in System Settings."
        case .unasked: "macOS hasn’t asked you yet."
        case .unknown: "Openspot can’t read whether macOS gives it."
        }
    }

    public static func word(of readiness: SpotReadiness) -> String {
        switch readiness {
        case .access: "Needs access"
        case .review: "Needs review"
        case .off: "Off"
        case .ready: "Ready"
        }
    }

    public static func purpose(of use: SpotUse) -> String {
        switch use {
        case .app: "Changes Openspot"
        case .spots: "Reads and changes your spots"
        case .screen: "Sees and moves what is on the screen"
        case .clipboard: "Reads and writes the clipboard"
        case .calendar: "Reads your calendars and reminders"
        case .power: "Keeps the Mac awake"
        case .network: "Reaches the internet"
        case .files: "Reads and writes files"
        case .timer: "Runs at a time"
        case .attachment: "Takes what you hand on"
        case .read: "Reads what you work on"
        case .account: "Signs what you publish"
        }
    }

    public static func lack(of standing: SettingsFacts.Standing, in facts: SettingsFacts) -> String {
        if standing.readiness == .review {
            return standing.refused.isEmpty ? "Made a call it doesn’t declare" : "Tried \(standing.refused.map(\.rawValue).joined(separator: ", ")), which it doesn’t declare"
        }
        return "Needs \(facts.names(standing.needs))"
    }

    public static func caps(_ key: String) -> [String] {
        guard !key.isEmpty, key != "none" else { return [] }
        var words = key.lowercased().split(separator: "+").map(String.init)
        let name = words.popLast() ?? ""
        let marks = [("ctrl", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("cmd", "⌘")].filter { words.contains($0.0) }.map(\.1)
        let names = ["space": "Space", "return": "↩", "tab": "⇥", "backspace": "⌫", "escape": "Esc", "left": "←", "right": "→", "up": "↑", "down": "↓", "shake": "Shake"]
        return marks + [names[name] ?? (name.count == 1 ? name.uppercased() : name.capitalized)]
    }
}
