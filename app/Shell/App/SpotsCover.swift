import AppKit
import OpenspotCore
import SwiftUI

/// The wallpaper of each screen, drawn over the other apps while Edit Spots shows, so that only the panel and the store are
/// seen. It joins every Space, full-screen ones too, lies just under the panel, and a click on it ends Edit Spots. While the
/// panel shows, it decodes its pictures and builds its windows off the screen, so that a press only orders them in, and it
/// lets them go when the panel hides.
@MainActor
final class SpotsCover {
    /// One screen's frame and the wallpaper decoded for it.
    private struct Screen {
        let frame: NSRect
        let url: URL?
        let picture: CGImage?
    }

    private var windows: [NSWindow] = []
    private let look = Look()
    private var screens: [Screen]?
    private var load: Task<[Screen], Never>?
    private weak var panel: NSWindow?
    private var onClick: (() -> Void)?
    private var isWanted = false

    /// Decodes each screen's wallpaper off the main thread and builds its window, unless the windows it holds show the same
    /// files.
    func prepare() {
        let wanted = NSScreen.screens.map { screen in
            (frame: screen.frame, url: NSWorkspace.shared.desktopImageURL(for: screen), side: max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor)
        }
        if let screens, screens.map(\.frame) == wanted.map(\.frame), screens.map(\.url) == wanted.map(\.url) { return }
        if load != nil, screens == nil { return }
        let load = Task.detached(priority: .utility) {
            wanted.map { screen in Screen(frame: screen.frame, url: screen.url, picture: screen.url.flatMap { Self.picture(at: $0, side: screen.side) }) }
        }
        self.load?.cancel()
        self.load = load
        Task { [weak self] in
            let screens = await load.value
            guard let self, self.load == load else { return }
            self.build(screens)
        }
    }

    /// Lets the windows and the pictures go, while the cover does not show.
    func release() {
        guard !isWanted else { return }
        load?.cancel()
        load = nil
        screens = nil
        close()
    }

    /// Orders the cover in under this window and fades it in on the next turn, with the motion that starts there. A cover
    /// whose windows are not built yet shows once they are.
    func show(under panel: NSWindow, onClick: @escaping () -> Void) {
        guard !isWanted else { return }
        isWanted = true
        self.panel = panel
        self.onClick = onClick
        if screens == nil {
            prepare()
        } else {
            present()
        }
    }

    /// Fades the cover out, then takes its windows off the screen and keeps them for the next show.
    func hide() {
        guard isWanted else { return }
        isWanted = false
        withAnimation(SpotMotion.move) {
            look.isOut = false
        } completion: { [weak self] in
            guard let self, !self.isWanted else { return }
            for window in self.windows { window.orderOut(nil) }
        }
    }

    /// Builds a window off the screen for each screen's wallpaper, and shows them when the cover is wanted.
    private func build(_ screens: [Screen]) {
        close()
        self.screens = screens
        windows = screens.map { screen in
            Self.window(frame: screen.frame, view: Wallpaper(look: look, picture: screen.picture) { [weak self] in self?.onClick?() })
        }
        if isWanted { present() }
    }

    private func present() {
        guard let panel else { return }
        for window in windows {
            window.level = panel.level
            window.order(.below, relativeTo: panel.windowNumber)
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isWanted else { return }
            withAnimation(SpotMotion.move) { self.look.isOut = true }
        }
    }

    private func close() {
        for window in windows { window.orderOut(nil) }
        windows = []
    }

    private static func window(frame: NSRect, view: Wallpaper) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setFrame(frame, display: false)
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
        return window
    }

    /// The wallpaper at this file, decoded no larger than this many pixels on its long side.
    nonisolated private static func picture(at url: URL, side: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(side.rounded(.up)),
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// Whether the cover shows.
    @MainActor @Observable fileprivate final class Look {
        var isOut = false

        nonisolated deinit {}
    }
}

/// One screen's wallpaper, filling the screen, or black when the wallpaper is no picture that can be read.
private struct Wallpaper: View {
    let look: SpotsCover.Look
    let picture: CGImage?
    let onClick: () -> Void

    var body: some View {
        Group {
            if let picture {
                Image(decorative: picture, scale: 1)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.black
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture(perform: onClick)
        .opacity(look.isOut ? 1 : MotionTokens.hiddenOpacity)
    }
}
