import AppKit
import OpenspotCore
import SwiftUI

/// The wallpaper of each screen, drawn over the other apps while Edit Spots shows, so that only the panel and the store are
/// seen. It joins every Space, full-screen ones too, lies just under the panel, and a click on it ends Edit Spots. It decodes
/// its pictures while the panel shows, so that a press finds them, and lets them go when the panel hides.
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
    private var isWanted = false

    /// Decodes each screen's wallpaper off the main thread, unless the pictures it holds are of the same files.
    func prepare() {
        let wanted = NSScreen.screens.map { screen in
            (frame: screen.frame, url: NSWorkspace.shared.desktopImageURL(for: screen), side: max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor)
        }
        if let screens, screens.map(\.frame) == wanted.map(\.frame), screens.map(\.url) == wanted.map(\.url) { return }
        load?.cancel()
        load = Task.detached(priority: .utility) {
            wanted.map { screen in Screen(frame: screen.frame, url: screen.url, picture: screen.url.flatMap { Self.picture(at: $0, side: screen.side) }) }
        }
        let load = load
        Task { [weak self] in
            guard let screens = await load?.value, let self, self.load == load else { return }
            self.screens = screens
        }
    }

    /// Lets the pictures go, while the cover does not show.
    func release() {
        guard !isWanted else { return }
        load?.cancel()
        load = nil
        screens = nil
    }

    /// Lays the cover under this window and fades it in on the next turn, with the motion that starts there. Pictures that
    /// are not decoded yet are waited for.
    func show(under panel: NSWindow, onClick: @escaping () -> Void) {
        guard !isWanted else { return }
        isWanted = true
        if screens == nil, load == nil { prepare() }
        Task { [weak self, weak panel] in
            if self?.screens == nil, let load = self?.load {
                let screens = await load.value
                if self?.screens == nil { self?.screens = screens }
            }
            guard let self, let panel, self.isWanted, let screens = self.screens else { return }
            self.close()
            self.windows = screens.map { screen in
                Self.window(frame: screen.frame, view: Wallpaper(look: self.look, picture: screen.picture, onClick: onClick), level: panel.level)
            }
            for window in self.windows { window.order(.below, relativeTo: panel.windowNumber) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isWanted else { return }
                withAnimation(SpotMotion.move) { self.look.isOut = true }
            }
        }
    }

    /// Fades the cover out, then takes its windows off the screen.
    func hide() {
        guard isWanted else { return }
        isWanted = false
        withAnimation(SpotMotion.move) {
            look.isOut = false
        } completion: { [weak self] in
            guard let self, !self.isWanted else { return }
            self.close()
        }
    }

    private func close() {
        for window in windows { window.orderOut(nil) }
        windows = []
    }

    private static func window(frame: NSRect, view: Wallpaper, level: NSWindow.Level) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = level
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        window.contentView = hosting
        window.setFrame(frame, display: false)
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
