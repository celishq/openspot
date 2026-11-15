import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class SpotPicture {
    static let isOnScreen = ProcessInfo.processInfo.environment["OPENSPOT_PICTURE_ON_SCREEN"] != nil
    private static let glassSettle = 1.0
    private static let lifeLimit = 30.0
    private static let shotLimit = 10.0
    private static let far = CGPoint(x: -9000, y: -9000)
    private static let level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

    private let view: NSView
    private let windows: [NSWindow]
    private let path: String

    static func start() {
        NSApplication.shared.setActivationPolicy(isOnScreen ? .accessory : .prohibited)
        guard isOnScreen else { return }
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        DispatchQueue.global().asyncAfter(deadline: .now() + lifeLimit) { exit(1) }
    }

    init(of content: some View, size: CGSize, path: String) {
        self.path = path
        let root = content
            .environment(\.spotDrawsGlass, Self.isOnScreen)
            .preferredColorScheme(.dark)
        let view = NSHostingView(rootView: root)
        self.view = view
        guard Self.isOnScreen else {
            let window = NSWindow(contentRect: NSRect(origin: Self.far, size: size), styleMask: .borderless, backing: .buffered, defer: false)
            window.contentView = view
            window.orderBack(nil)
            windows = [window]
            return
        }
        guard let screen = NSScreen.screens.first, size.width <= screen.frame.width, size.height <= screen.frame.height else {
            FileHandle.standardError.write(Data("The main screen has no room for a picture of \(Int(size.width)) by \(Int(size.height)).\n".utf8))
            exit(1)
        }
        let origin = CGPoint(x: (screen.frame.midX - size.width / 2).rounded(), y: (screen.frame.midY - size.height / 2).rounded())
        let frame = NSRect(origin: origin, size: size)
        let cover = Pane(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        cover.contentView = NSHostingView(rootView: SpotWallpaper(seed: URL(fileURLWithPath: path).lastPathComponent))
        cover.level = Self.level
        let glass = Pane(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        glass.isOpaque = false
        glass.backgroundColor = .clear
        glass.contentView = view
        glass.level = NSWindow.Level(rawValue: Self.level.rawValue + 1)
        windows = [cover, glass]
        for window in windows {
            window.hasShadow = false
            window.ignoresMouseEvents = true
            window.hidesOnDeactivate = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.orderFrontRegardless()
        }
    }

    func save(after settle: Double) {
        DispatchQueue.main.asyncAfter(deadline: .now() + settle + (Self.isOnScreen ? Self.glassSettle : 0)) {
            MainActor.assumeIsolated {
                guard Self.isOnScreen else { exit(self.draw() ? 0 : 1) }
                Task { exit(await self.shoot() ? 0 : 1) }
            }
        }
    }

    private func draw() -> Bool {
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return false }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        return FileManager.default.createFile(atPath: path, contents: bitmap.representation(using: .png, properties: [:]))
    }

    private func shoot() async -> Bool {
        guard let frame = windows.last?.frame, let screen = NSScreen.screens.first else { return false }
        let rect = [frame.minX, screen.frame.maxY - frame.maxY, frame.width, frame.height].map { String(Int($0)) }.joined(separator: ",")
        let tool = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let file = URL(fileURLWithPath: path).path
        try? FileManager.default.removeItem(atPath: file)
        _ = try? await ScriptProcess.output(url: tool, arguments: ["-x", "-R", rect, file], limit: Self.shotLimit)
        return FileManager.default.fileExists(atPath: file)
    }

    private final class Pane: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }
}
