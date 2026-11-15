import AppKit
import OpenspotCore
import SwiftUI

@MainActor
final class SpotPicture {
    static let isOnScreen = ProcessInfo.processInfo.environment["OPENSPOT_PICTURE_ON_SCREEN"] != nil
    private static let glassSettle = 1.0
    private static let focusLimit = 2.0
    private static let focusSettle = 0.5
    private static let accent = 5
    private static let scale: CGFloat = 2
    private static let sameColour = 0.08
    private static let probes = 9
    private static let panelProbes = 3
    private static let lifeLimit = 30.0
    private static let shotLimit = 10.0
    private static let far = CGPoint(x: -9000, y: -9000)
    private static let level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))

    private let view: NSView
    private let windows: [NSWindow]
    private let path: String
    private let seed: String

    static func start() {
        NSApplication.shared.setActivationPolicy(isOnScreen ? .accessory : .prohibited)
        guard isOnScreen else { return }
        var given = UserDefaults.standard.volatileDomain(forName: UserDefaults.argumentDomain)
        given["AppleAccentColor"] = accent
        UserDefaults.standard.setVolatileDomain(given, forName: UserDefaults.argumentDomain)
        NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        DispatchQueue.global().asyncAfter(deadline: .now() + lifeLimit) { _exit(1) }
    }

    init(of content: some View, size: CGSize, path: String) {
        self.path = path
        seed = URL(fileURLWithPath: path).lastPathComponent
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
            FileHandle.standardError.write(Data("Openspot cannot take the picture: the main screen has no room for \(Int(size.width)) by \(Int(size.height)) points.\n".utf8))
            exit(1)
        }
        guard screen.backingScaleFactor == Self.scale else {
            FileHandle.standardError.write(Data("Openspot cannot take the picture: the main screen draws at \(Int(screen.backingScaleFactor))x. Run this on a Mac whose main screen draws at 2x.\n".utf8))
            exit(1)
        }
        let origin = CGPoint(x: (screen.frame.midX - size.width / 2).rounded(), y: (screen.frame.midY - size.height / 2).rounded())
        let frame = NSRect(origin: origin, size: size)
        let cover = Pane(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        cover.contentView = NSHostingView(rootView: SpotWallpaper(seed: seed))
        cover.level = Self.level
        let glass = FocusedPane(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        glass.isOpaque = false
        glass.backgroundColor = .clear
        glass.contentView = view
        glass.level = NSWindow.Level(rawValue: Self.level.rawValue + 1)
        windows = [cover, glass]
        cover.ignoresMouseEvents = true
        for window in windows {
            window.hasShadow = false
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
        guard let glass = windows.last, let screen = NSScreen.screens.first else { return false }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        glass.makeKey()
        let limit = ContinuousClock.now + .seconds(Self.focusLimit)
        while !glass.isKeyWindow {
            guard ContinuousClock.now < limit else { return Self.fail("The picture's window did not take the focus.") }
            try? await Task.sleep(for: .milliseconds(10))
        }
        try? await Task.sleep(for: .seconds(Self.focusSettle))
        guard glass.isKeyWindow else { return Self.fail("The picture's window lost the focus before the shot.") }
        let frame = glass.frame
        let rect = [frame.minX, screen.frame.maxY - frame.maxY, frame.width, frame.height].map { String(Int($0)) }.joined(separator: ",")
        let tool = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let shot = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-picture-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: shot) }
        var fault: String?
        do {
            _ = try await ScriptProcess.output(url: tool, arguments: ["-x", "-R", rect, shot.path], limit: Self.shotLimit)
        } catch {
            fault = "\(error)"
        }
        let kept = glass.isKeyWindow
        for window in windows { window.orderOut(nil) }
        if let fault { return Self.fail("Openspot cannot take the picture: `screencapture` failed (\(fault)). The old picture is kept.") }
        guard kept else { return Self.fail("The picture's window lost the focus during the shot. The old picture is kept. Run the script again.") }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == front, !NSApplication.shared.isActive else {
            return Self.fail("The picture changed the app at the front. The old picture is kept.")
        }
        guard holdsPanel(shot, size: frame.size) else {
            return Self.fail("The shot shows no Openspot window, so the old picture is kept. Allow Screen Recording for the app that runs this script, in Privacy & Security.")
        }
        let file = URL(fileURLWithPath: path)
        _ = try? FileManager.default.removeItem(at: file)
        do {
            try FileManager.default.moveItem(at: shot, to: file)
        } catch {
            return Self.fail("Openspot cannot write \(file.path): \(error.localizedDescription)")
        }
        return true
    }

    private func holdsPanel(_ shot: URL, size: CGSize) -> Bool {
        let renderer = ImageRenderer(content: SpotWallpaper(seed: seed).frame(width: size.width, height: size.height))
        renderer.scale = Self.scale
        guard let data = try? Data(contentsOf: shot), let taken = NSBitmapImageRep(data: data), let plain = renderer.cgImage.map(NSBitmapImageRep.init(cgImage:)),
              taken.pixelsWide == plain.pixelsWide, taken.pixelsHigh == plain.pixelsHigh else { return false }
        let differs = { (x: Int, y: Int) -> Bool in
            guard let one = taken.colorAt(x: x, y: y)?.usingColorSpace(.sRGB), let other = plain.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return true }
            return max(abs(one.redComponent - other.redComponent), abs(one.greenComponent - other.greenComponent), abs(one.blueComponent - other.blueComponent)) > Self.sameColour
        }
        let far = (x: taken.pixelsWide - 3, y: taken.pixelsHigh - 3)
        guard ![(2, 2), (far.x, 2), (2, far.y), (far.x, far.y)].contains(where: { differs($0.0, $0.1) }) else { return false }
        let inner = (1..<Self.probes).flatMap { row in (1..<Self.probes).map { (taken.pixelsWide * $0 / Self.probes, taken.pixelsHigh * row / Self.probes) } }
        return inner.count { differs($0.0, $0.1) } >= Self.panelProbes
    }

    private static func fail(_ words: String) -> Bool {
        FileHandle.standardError.write(Data("\(words)\n".utf8))
        return false
    }

    private final class Pane: NSPanel {
        override var canBecomeKey: Bool { false }
        override var canBecomeMain: Bool { false }
    }

    private final class FocusedPane: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }

        override func sendEvent(_ event: NSEvent) {}

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            true
        }
    }
}
