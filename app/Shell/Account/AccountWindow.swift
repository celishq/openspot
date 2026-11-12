import AppKit
import LocalAuthentication
import OpenspotCore
import SwiftUI

/// The account window: one at a time, on the step that opened it. Seeing the words of a kept key or signing out first
/// asks for Touch ID or the Mac password.
@MainActor
final class AccountWindow: NSObject, NSWindowDelegate {
    private static var shown: AccountWindow?

    private let window: NSWindow
    private let flow: AccountFlow
    private let store: AccountStore
    private var closed: [CheckedContinuation<Void, Never>] = []

    private init(step: AccountFlow.Step, store: AccountStore) {
        self.store = store
        flow = AccountFlow(store: store, step: step)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "Account"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AccountView(flow: flow, close: { [weak self] in self?.window.close() }))
        window.delegate = self
        window.center()
    }

    /// Shows the window on a step, and returns once it closes, with whether the Mac then holds a key.
    static func show(_ step: AccountFlow.Step, store: AccountStore) async -> Bool {
        if step == .words || step == .signOut {
            guard (try? store.key()) != nil else { return false }
            guard await allows(step == .words ? "show your account words" : "sign out of your account") else { return true }
        }
        shown?.window.close()
        let account = AccountWindow(step: step, store: store)
        shown = account
        AppPresence.open()
        account.window.makeKeyAndOrderFront(nil)
        await withCheckedContinuation { account.closed.append($0) }
        return (try? store.key()) != nil
    }

    /// Asks for Touch ID or the Mac password. A Mac with neither allows it.
    private static func allows(_ reason: String) async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) == true
    }

    func windowWillClose(_ notification: Notification) {
        if Self.shown === self { Self.shown = nil }
        AppPresence.close()
        closed.forEach { $0.resume() }
        closed = []
    }
}
