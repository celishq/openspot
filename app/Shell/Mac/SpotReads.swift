import AppKit
import ApplicationServices
import CoreServices
import OpenspotCore

struct SpotReads: MacReads {
    private static let queue = DispatchQueue(label: "openspot.reads")
    private static let timeout: Float = 1

    let frontApp: @MainActor @Sendable () -> FrontApp?

    func front() async -> FrontApp? {
        await MainActor.run { frontApp() }
    }

    func name(of bundleID: String) -> String? {
        guard let place = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        return (FileManager.default.displayName(atPath: place.path) as NSString).deletingPathExtension
    }

    func place(of bundleID: String) -> String? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)?.path
    }

    func access(to bundleID: String, asks: Bool) async -> AccessStatus {
        await Self.off { Self.access(to: bundleID, asks: asks) }
    }

    func run(_ script: String) async -> [String]? {
        await Self.off { Self.run(script) }
    }

    func accessibility(asks: Bool) -> AccessStatus {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": asks] as CFDictionary) ? .allowed : .unasked
    }

    func selectedText(of bundleID: String) async -> String? {
        guard let pid = await MainActor.run(body: { NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first?.processIdentifier }) else { return nil }
        return await Self.off { Self.selectedText(of: pid) }
    }

    private static func off<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value {
        await withCheckedContinuation { done in
            queue.async { done.resume(returning: autoreleasepool(invoking: work)) }
        }
    }

    private static func access(to bundleID: String, asks: Bool) -> AccessStatus {
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
