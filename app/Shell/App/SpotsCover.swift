import AppKit
import OpenspotCore
import SwiftUI

/// The wallpaper of each screen, drawn over the other apps while Edit Spots shows, so that only the panel and the store are
/// seen. It joins every Space, full-screen ones too, lies just under the panel, and a click on it ends Edit Spots. It holds
/// its pictures only while it shows.
@MainActor
final class SpotsCover {
    private var windows: [NSWindow] = []
    private let look = Look()
    private var load: Task<Void, Never>?
    private var isWanted = false

    /// Reads each screen's wallpaper off the main thread, then lays the cover under this window and fades it in.
    func show(under panel: NSWindow, onClick: @escaping () -> Void) {
        guard !isWanted else { return }
        isWanted = true
        load?.cancel()
        let screens = NSScreen.screens.map { screen in
            (frame: screen.frame, url: NSWorkspace.shared.desktopImageURL(for: screen), side: max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor)
        }
        load = Task { [weak self, weak panel] in
            let pictures = await Task.detached(priority: .userInitiated) {
                screens.map { screen in screen.url.flatMap { Self.picture(at: $0, side: screen.side) } }
            }.value
            guard let self, let panel, self.isWanted, !Task.isCancelled else { return }
            self.close()
            self.windows = zip(screens, pictures).map { screen, picture in
                Self.window(frame: screen.frame, view: Wallpaper(look: self.look, picture: picture, onClick: onClick), level: panel.level)
            }
            for window in self.windows { window.order(.below, relativeTo: panel.windowNumber) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isWanted else { return }
                withAnimation(SpotMotion.move) { self.look.isOut = true }
            }
        }
    }

    /// Fades the cover out, then takes its windows off the screen and lets its pictures go.
    func hide() {
        guard isWanted else { return }
        isWanted = false
        load?.cancel()
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
