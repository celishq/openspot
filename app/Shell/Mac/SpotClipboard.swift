import AppKit
import ApplicationServices
import OpenspotCore

/// The clipboard for a script. It copies a file as Finder does, with the picture of an image, reads the text, and pastes into
/// the front app with a ⌘V key event, which needs Accessibility. It runs on the thread of its call.
enum SpotClipboard {
    static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    private static let vKey: CGKeyCode = 9

    /// Copies the file, and fails when it is missing or the pasteboard does not take it.
    static func copy(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw SpotError.fault("Openspot cannot find \(url.lastPathComponent).") }
        guard copy(url, to: .general) else { throw SpotError.fault("Openspot could not copy \(url.lastPathComponent). Copy it from Finder instead.") }
    }

    static func copy(text: String) throws {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { throw SpotError.fault("Openspot could not copy the text. Try again.") }
    }

    /// The text on the clipboard, or nothing when it holds none.
    static func text() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    /// Posts the key events of ⌘V. With no Accessibility it fails with the fix.
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

    /// Puts the file on the pasteboard as one item: its URL, and the picture when it is an image. The pasteboard takes a file
    /// URL after the write returns, and a process that exits at once loses it, so this reads the URL back before it answers.
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
