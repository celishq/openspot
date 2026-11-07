import AppKit
import ApplicationServices

/// The clipboard for a script. It copies a file as Finder does, with the picture of an image, and pastes it into the front
/// app with a ⌘V key event, which needs Accessibility.
@MainActor
enum SpotClipboard {
    private static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    private static let vKey: CGKeyCode = 9

    /// Copies the file, then pastes it. A missing file or a missing permission prints the reason, and exits with 1.
    static func paste(_ path: String) -> Never {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { fail("Openspot cannot find \(url.lastPathComponent).") }
        guard copy(url, to: .general) else { fail("Openspot could not copy \(url.lastPathComponent). Copy it from Finder instead.") }
        guard AXIsProcessTrusted() else {
            print("open=\(accessibility)")
            fail("Copied, but Openspot cannot paste. Press `⌘V`, or allow Openspot in Accessibility.")
        }
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        exit(0)
    }

    /// Puts the file on the pasteboard as one item: its URL, and the picture when it is an image.
    static func copy(_ url: URL, to pasteboard: NSPasteboard) -> Bool {
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        if let picture = NSImage(contentsOf: url)?.tiffRepresentation {
            item.setData(picture, forType: .tiff)
            if url.pathExtension.lowercased() == "png", let data = try? Data(contentsOf: url) { item.setData(data, forType: .png) }
        }
        pasteboard.clearContents()
        return pasteboard.writeObjects([item])
    }

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }
}
