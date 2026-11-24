import AppKit
import ApplicationServices
import OpenspotCore

struct SpotClipboard: MacClipboard {
    static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
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

    func contents() -> ClipboardContents {
        let board = NSPasteboard.general
        let types = board.types ?? []
        guard !types.contains(Self.concealed) else { return .none }
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty { return .files(urls) }
        if types.contains(.string) { return .text }
        if types.contains(.png) { return .image("png") }
        if types.contains(.tiff) { return .image("tiff") }
        return .none
    }

    func count() -> Int {
        NSPasteboard.general.changeCount
    }

    func image() -> Data? {
        NSPasteboard.general.data(forType: .png) ?? NSPasteboard.general.data(forType: .tiff)
    }

    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")

    func paste() throws {
        guard AXIsProcessTrusted() else {
            throw SpotError.failedWithFix(1, "Openspot cannot paste. Press `⌘V` to paste, or allow Openspot in Accessibility.", URL(string: Self.accessibility)!)
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
