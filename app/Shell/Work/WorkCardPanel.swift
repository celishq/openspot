import AppKit
import OpenspotCore
import SwiftUI

final class WorkCardPanel: NSPanel {
    private static let margin: CGFloat = 20
    private static let size = NSSize(width: WorkCardView.side + 2 * margin, height: WorkCardView.side + 2 * margin)

    private let stage = WorkCardStage()
    private var model: SpotsModel?
    private var shows = 0

    private func watch() {
        guard let model else { return }
        let card = withObservationTracking {
            model.workCard
        } onChange: { [weak self] in
            Task { @MainActor in self?.watch() }
        }
        if let card { show(card) } else { hide() }
    }

    private func show(_ card: WorkCard) {
        stage.card = card
        guard !stage.isShown else { return }
        shows += 1
        let current = shows
        let place = ScreenPlace(screens: ScreenPlace.Screen.all)
        if let origin = place.origin(ofWorkCard: Self.size, pointer: NSEvent.mouseLocation) {
            setFrameOrigin(origin)
        }
        orderFrontRegardless()
        DispatchQueue.main.async {
            if self.shows == current { self.stage.isShown = true }
        }
    }

    private func hide() {
        guard stage.card != nil else { return }
        shows += 1
        let current = shows
        stage.isShown = false
        DispatchQueue.main.asyncAfter(deadline: .now() + MotionTokens.fadeOut) {
            guard self.shows == current else { return }
            self.stage.card = nil
            self.orderOut(nil)
        }
    }

    static func make(model: SpotsModel) -> WorkCardPanel {
        let panel = WorkCardPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let view = NSHostingView(rootView: WorkCardView(model: model, stage: panel.stage))
        view.sizingOptions = []
        panel.contentView = view
        panel.model = model
        panel.watch()
        return panel
    }
}
