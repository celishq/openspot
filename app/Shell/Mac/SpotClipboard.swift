import AppKit
import ApplicationServices
import OpenspotCore

struct SpotClipboard: MacClipboard {
    private static let vKey: CGKeyCode = 9
    private static let nKey: CGKeyCode = 45
    private static let returnKey: CGKeyCode = 36
    private static let settle: TimeInterval = 0.3

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

    func paste(opening: Bool, sending: Bool) throws {
        guard SpotAccessibility.ask() else {
            throw SpotError.failedWithFix(1, "Openspot cannot paste. Press `⌘V` to paste, or allow Openspot in Accessibility.", SpotAccessibility.settings)
        }
        if opening {
            Self.press(Self.commandCode(of: "n") ?? Self.nKey, flags: .maskCommand)
            Thread.sleep(forTimeInterval: Self.settle)
        }
        Self.press(Self.commandCode(of: "v") ?? Self.vKey, flags: .maskCommand)
        if sending {
            Thread.sleep(forTimeInterval: Self.settle)
            Self.press(Self.returnKey, flags: [])
        }
    }

    private static func commandCode(of character: Character) -> CGKeyCode? {
        let read = { MainActor.assumeIsolated { SpotKeyLayouts.readCommandCode(of: character) } }
        return Thread.isMainThread ? read() : DispatchQueue.main.sync(execute: read)
    }

    private static func press(_ code: CGKeyCode, flags: CGEventFlags) {
        for isDown in [true, false] {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: isDown)
            event?.flags = flags
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
