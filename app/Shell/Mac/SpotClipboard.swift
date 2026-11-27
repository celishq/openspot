import AppKit
import ApplicationServices
import OpenspotCore
import Synchronization

struct SpotClipboard: MacClipboard {
    static let accessibility = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    private static let vKey: CGKeyCode = 9
    private static let board = Mutex(())

    func copy(file url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw SpotError.fault("Openspot cannot find \(url.lastPathComponent).") }
        guard autoreleasepool(invoking: { Self.board.withLock { _ in Self.copy(url, to: .general) } }) else { throw SpotError.fault("Openspot could not copy \(url.lastPathComponent). Copy it from Finder instead.") }
    }

    func copy(text: String) throws {
        let isCopied = Self.board.withLock { _ in
            NSPasteboard.general.clearContents()
            return NSPasteboard.general.setString(text, forType: .string)
        }
        guard isCopied else { throw SpotError.fault("Openspot could not copy the text. Try again.") }
    }

    func text() -> String {
        Self.board.withLock { _ in NSPasteboard.general.string(forType: .string) ?? "" }
    }

    func types() -> Set<String> {
        Self.board.withLock { _ in Set(NSPasteboard.general.types?.map(\.rawValue) ?? []) }
    }

    func files() -> [URL] {
        Self.board.withLock { _ in NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? [] }
    }

    func count() -> Int {
        Self.board.withLock { _ in NSPasteboard.general.changeCount }
    }

    func image() -> Data? {
        Self.board.withLock { _ in NSPasteboard.general.data(forType: .png) ?? NSPasteboard.general.data(forType: .tiff) }
    }

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

    static func write(_ objects: [any NSPasteboardWriting]) {
        board.withLock { _ in
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects(objects)
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
