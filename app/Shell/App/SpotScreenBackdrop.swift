import AppKit
import OpenspotCore
import SwiftUI

final class SpotScreenBackdrop: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    static func make(model: SpotsModel) -> SpotScreenBackdrop {
        let window = SpotScreenBackdrop(contentRect: NSScreen.main?.frame ?? .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.ignoresMouseEvents = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: ScreenBackdropView(model: model))
        hosting.sizingOptions = []
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        return window
    }

    func show(on screen: NSScreen?, below panel: NSWindow) {
        if let frame = screen?.frame, frame != self.frame { setFrame(frame, display: false) }
        order(.below, relativeTo: panel.windowNumber)
    }
}

private struct ScreenBackdropView: View {
    let model: SpotsModel

    var body: some View {
        ZStack {
            switch SpotTokens.backdrop.style {
            case .blur:
                SpotBackdropBlur(radius: SpotTokens.backdrop.blur)
                SpotTheme.backdropVeil
            case .tint: SpotTheme.backdropTint
            }
        }
        .modifier(SpotShownFade(isShown: model.isShown))
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .id(SpotLoadedTheme.shared.layout)
    }
}
