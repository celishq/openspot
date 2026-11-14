import AppKit
import ApplicationServices
import OpenspotCore

enum SpotClipboard {
    static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    private static let vKey: CGKeyCode = 9

    static func copy(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw SpotError.fault("Openspot cannot find \(url.lastPathComponent).") }
        guard autoreleasepool(invoking: { copy(url, to: .general) }) else { throw SpotError.fault("Openspot could not copy \(url.lastPathComponent). Copy it from Finder instead.") }
    }

    static func copy(text: String) throws {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { throw SpotError.fault("Openspot could not copy the text. Try again.") }
    }

    static func text() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    static func paste() throws {
        guard AXIsProcessTrusted() else {
            throw SpotError.failedWithFix(1, "Openspot cannot paste. Press `⌘V` to paste, or allow Openspot in Accessibility.", URL(string: accessibility)!)
        }
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
    }

    static func copy(_ url: URL, to pasteboard: NSPasteboard) -> Bool {
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        if let picture = NSImage(contentsOf: url)?.tiffRepresentation {
            item.setData(picture, forType: .tiff)
            if url.pathExtension.lowercased() == "png", let data = try? Data(contentsOf: url) { item.setData(data, forType: .png) }
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item]) && pasteboard.string(forType: .fileURL) == url.absoluteString
    }
}
