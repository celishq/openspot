import Foundation

public enum SpotUse: String, CaseIterable, Codable, Sendable {
    case app, spots, screen, clipboard, calendar, power, network, files, timer, attachment, read, timeline
    case account

    static func reachesAccountKey(_ uses: Set<SpotUse>, isBuiltIn: Bool) -> Bool {
        isBuiltIn && uses.contains(.account)
    }

    static func set(_ words: [String], of name: String) throws -> Set<SpotUse> {
        var uses: Set<SpotUse> = []
        for word in words {
            guard let use = SpotUse(rawValue: word) else {
                let known = allCases.filter { $0 != .account }.map(\.rawValue)
                throw SpotError.fault("\(name) has an unknown use in its uses: \(word). Use \(known.dropLast().joined(separator: ", ")) or \(known.last ?? "")")
            }
            uses.insert(use)
        }
        return uses
    }

    public var title: String {
        switch self {
        case .app: "Openspot"
        case .spots: "Other Spots"
        case .screen: "Screen"
        case .clipboard: "Clipboard"
        case .calendar: "Calendars & Reminders"
        case .power: "Power"
        case .timer: "Timers"
        case .attachment: "Panel Field"
        case .read: "What You’re Working On"
        case .timeline: "Timeline"
        case .network: "Network"
        case .files: "Files"
        case .account: "Account Key"
        }
    }

    public var purpose: String {
        switch self {
        case .app: "Change Openspot itself: quit or update it, or change its theme, its keys or the menu bar."
        case .spots: "Add, remove, change or run other spots, read their logs, and read or change their settings."
        case .screen: "Take a picture or a recording of the screen, read or move windows, and pick a colour."
        case .clipboard: "Copy, paste and read the clipboard."
        case .calendar: "Read and add events and reminders."
        case .power: "Keep the Mac awake with its lid closed."
        case .timer: "Add, list and remove its timers."
        case .attachment: "Put a value in the panel’s field when the panel opens or Tab picks its chip."
        case .read: "Read what people work on: the front tab, the files selected in Finder and the selected text."
        case .timeline: "Add to its own timeline and read it back, and run on its events also while the panel is closed. Only you can pause the timeline or change how long it keeps."
        case .network: "Reach the network, such as with env.fetch."
        case .files: "Write outside its data folder. No command needs it."
        case .account: "Sign what you publish with the account key."
        }
    }
}
