import AppKit
import ApplicationServices
import CoreServices
import OpenspotCore

struct SpotReads: MacReads {
    private static let queue = DispatchQueue(label: "openspot.reads")
    private static let timeout: Float = 1

    let previous: @MainActor @Sendable () -> NSRunningApplication?

    func front() async -> FrontApp? {
        await MainActor.run { app().flatMap { app in app.bundleIdentifier.map { FrontApp(bundleID: $0, path: app.bundleURL?.path) } } }
    }

    func isInstalled(_ bundleID: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    func access(to bundleID: String, asks: Bool) async -> ReadAccess {
        await Self.off { Self.access(to: bundleID, asks: asks) }
    }

    func run(_ script: String) async -> [String]? {
        await Self.off { Self.run(script) }
    }

    func accessibility(asks: Bool) -> ReadAccess {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": asks] as CFDictionary) ? .allowed : .unasked
    }

    func selectedText() async -> String? {
        guard let pid = await MainActor.run(body: { app()?.processIdentifier }) else { return nil }
        return await Self.off { Self.selectedText(of: pid) }
    }

    func copyCount() -> Int {
        NSPasteboard.general.changeCount
    }

    func copiedText() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    @MainActor
    private func app() -> NSRunningApplication? {
        let front = NSWorkspace.shared.frontmostApplication
        return front == .current ? previous() : front
    }

    private static func off<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value {
        await withCheckedContinuation { done in
            queue.async { done.resume(returning: autoreleasepool(invoking: work)) }
        }
    }

    private static func access(to bundleID: String, asks: Bool) -> ReadAccess {
        var target = AEAddressDesc()
        let id = Array(bundleID.utf8)
        guard AECreateDesc(DescType(typeApplicationBundleID), id, id.count, &target) == noErr else { return .unknown }
        defer { AEDisposeDesc(&target) }
        return switch Int(AEDeterminePermissionToAutomateTarget(&target, AEEventClass(kCoreEventClass), AEEventID(kAEGetData), asks)) {
        case Int(noErr): .allowed
        case errAEEventNotPermitted: .denied
        case errAEEventWouldRequireUserConsent: .unasked
        default: .unknown
        }
    }

    private static func run(_ script: String) -> [String]? {
        var error: NSDictionary?
        guard let result = NSAppleScript(source: script)?.executeAndReturnError(&error), error == nil else { return nil }
        guard result.descriptorType == typeAEList else { return result.stringValue.map { [$0] } }
        return result.numberOfItems == 0 ? [] : (1...result.numberOfItems).compactMap { result.atIndex($0)?.stringValue }
    }

    private static func selectedText(of pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, timeout)
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }
        var text: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused as! AXUIElement, kAXSelectedTextAttribute as CFString, &text) == .success else { return nil }
        return text as? String
    }
}
