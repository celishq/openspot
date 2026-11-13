import AppKit
import SwiftUI

/// The one floating panel that shows a tip above the whole window, so no bar or row ever covers it. It sits beside the
/// control, inside the window's edges.
@MainActor
final class TipPanel {
    static let shared = TipPanel()

    private let panel: NSPanel
    private let host = NSHostingView(rootView: TipLabel(text: ""))
    /// The control that the tip shows for, so a tip that a newer one replaced does not hide it.
    private var owner: UUID?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .floating
        panel.contentView = host
    }

    /// Shows a tip for a control at `frame`, in the window's top-left points, below it or above it.
    func show(_ text: String, for frame: CGRect, below: Bool, in window: NSWindow, owner: UUID) {
        self.owner = owner
        host.rootView = TipLabel(text: text)
        let size = host.fittingSize
        let height = window.contentView?.bounds.height ?? window.frame.height
        let control = window.convertToScreen(CGRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height))
        let edges = window.frame.insetBy(dx: 6, dy: 6)
        let x = min(max(control.midX - size.width / 2, edges.minX), edges.maxX - size.width)
        let y = below ? control.minY - 4 - size.height : control.maxY + 4
        panel.setFrame(CGRect(x: x, y: y, width: size.width, height: size.height), display: true)
        if panel.parent !== window {
            panel.parent?.removeChildWindow(panel)
            window.addChildWindow(panel, ordered: .above)
        }
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    func hide(owner: UUID) {
        guard self.owner == owner else { return }
        self.owner = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: { [panel] in
            MainActor.assumeIsolated { if panel.alphaValue == 0 { panel.orderOut(nil) } }
        })
    }
}

/// The words of a tip on a solid white card.
struct TipLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.black)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Color.black.opacity(0.08)))
            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
            .padding(8)
            .fixedSize()
    }
}
