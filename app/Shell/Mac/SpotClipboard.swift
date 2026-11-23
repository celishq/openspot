import AppKit
import ApplicationServices
import OpenspotCore

struct SpotClipboard: MacClipboard {
    private static let vKey: CGKeyCode = 9

    func copy(file url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw SpotError.fault("Openspot cannot find \(url.lastPathComponent).") }
        guard autoreleasepool(invoking: { Self.copy(url, to: .general) }) else { throw SpotError.fault("Openspot could not copy \(url.lastPathComponent). Copy it from Finder instead.") }
    }

    func copy(text: String) throws {
        NSPasteboard.general.clearContents()
        guard NSPasteboard.general.setString(text, forType: .string) else { throw SpotError.fault("Openspot could not copy the text. Try again.") }
    }

    func text() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    func paste() throws {
        guard SpotAccessibility.ask() else {
            throw SpotError.failedWithFix(1, "Openspot cannot paste. Press `⌘V` to paste, or allow Openspot in Accessibility.", SpotAccessibility.settings)
        }
        let read = { MainActor.assumeIsolated { SpotKeyLayouts.readCommandCode(of: "v") } }
        let code = (Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)) ?? Self.vKey
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: isDown)
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
