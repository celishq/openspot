import Foundation

public enum EventName {
    public static let frontApp = "app.front"
    public static let clipboard = "clipboard.change"
    public static let screenWake = "screen.wake"
    public static let appUpdate = "app.update"
    public static let appLaunch = "app.launch"
    public static let systemLoad = "system.load"
    public static let powerChange = "power.change"
    public static let diskMount = "disk.mount"
    public static let deviceConnect = "device.connect"
    public static let spotWant = "spot.want"
    public static let spotChange = "spot.change"

    public static let sheetOpen = "sheet.open"
    public static let panelOpen = "panel.open"
    public static let searchText = "search.text"
    public static let sheetText = "sheet.text"
    public static let attachmentPick = "attachment.pick"
    public static let itemPreview = "item.preview"
    public static let declarable = [sheetOpen, panelOpen, sheetText, itemPreview, spotWant, clipboard, frontApp, appUpdate, appLaunch, screenWake, systemLoad, powerChange, diskMount, deviceConnect]
    public static let valueless = [sheetOpen, sheetText, itemPreview, spotWant, clipboard, screenWake, appLaunch]

    public static func isName(_ word: String) -> Bool {
        let parts = word.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count > 1, parts.first?.first?.isLetter == true else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
        }
    }
}
