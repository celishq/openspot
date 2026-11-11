import AppKit
import ApplicationServices

/// The clipboard for a script. It copies a file as Finder does, with the picture of an image, reads the text, and pastes into
/// the front app with a ⌘V key event, which needs Accessibility.
@MainActor
enum SpotClipboard {
    static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    private static let vKey: CGKeyCode = 9
    /// The time the posted key events need to leave the process. An exit before it drops them.
    private static let postPause: TimeInterval = 0.1

    /// Copies the file. A missing file prints the reason, and exits with 1.
    static func copy(_ path: String) -> Never {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { fail("Openspot cannot find \(url.lastPathComponent).") }
        guard copy(url, to: .general) else { fail("Openspot could not copy \(url.lastPathComponent). Copy it from Finder instead.") }
        exit(0)
    }

    static func copy(text: String) -> Never {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { fail("Openspot could not copy the text. Try again.") }
        exit(0)
    }

    /// Prints the text on the clipboard, or nothing when it holds none, and exits.
    static func read() -> Never {
        FileHandle.standardOutput.write(Data((NSPasteboard.general.string(forType: .string) ?? "").utf8))
        exit(0)
    }

    /// Pastes the clipboard, and exits once the key events are posted. With no Accessibility it prints the fix, and exits with 1.
    static func paste() -> Never {
        guard AXIsProcessTrusted() else {
            print("link=\(accessibility)")
            fail("Openspot cannot paste. Press `⌘V` to paste, or allow Openspot in Accessibility.")
        }
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: vKey, keyDown: isDown)
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }
        Thread.sleep(forTimeInterval: postPause)
        exit(0)
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

    private static func fail(_ message: String) -> Never {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        exit(1)
    }
}
