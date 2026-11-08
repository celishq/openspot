#!/usr/bin/env swift
// name=Confetti
// symbol=party.popper
// subtitle=Celebrate on each screen
// key=k
import AppKit

let emission: TimeInterval = 1.5
let duration: TimeInterval = 4
let colors: [NSColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemTeal, .systemBlue, .systemPurple, .systemPink]

/// A small white rectangle that each cell tints with its colour.
func pieceImage() -> CGImage? {
    let size = NSSize(width: 10, height: 6)
    let image = NSImage(size: size, flipped: false) { rect in
        NSColor.white.setFill()
        rect.fill()
        return true
    }
    return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
}

/// The falling pieces of one colour.
func cell(_ color: NSColor, contents: CGImage?) -> CAEmitterCell {
    let cell = CAEmitterCell()
    cell.contents = contents
    cell.color = color.cgColor
    cell.birthRate = 12
    cell.lifetime = Float(duration)
    cell.velocity = 220
    cell.velocityRange = 120
    cell.yAcceleration = -320
    cell.emissionLongitude = -.pi / 2
    cell.emissionRange = .pi / 5
    cell.spin = 3
    cell.spinRange = 6
    cell.scaleRange = 0.5
    return cell
}

/// A clear window over one screen, which takes no click and no focus, with confetti that falls from its top edge.
func window(on screen: NSScreen, cells: [CAEmitterCell]) -> NSWindow {
    let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.level = .screenSaver
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

    let emitter = CAEmitterLayer()
    emitter.frame = CGRect(origin: .zero, size: screen.frame.size)
    emitter.emitterShape = .line
    emitter.emitterPosition = CGPoint(x: screen.frame.width / 2, y: screen.frame.height + 20)
    emitter.emitterSize = CGSize(width: screen.frame.width, height: 1)
    emitter.beginTime = CACurrentMediaTime()
    emitter.emitterCells = cells

    let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
    view.wantsLayer = true
    view.layer?.addSublayer(emitter)
    window.contentView = view
    window.orderFrontRegardless()
    DispatchQueue.main.asyncAfter(deadline: .now() + emission) { emitter.birthRate = 0 }
    return window
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let contents = pieceImage()
let cells = colors.map { cell($0, contents: contents) }
let windows = NSScreen.screens.map { window(on: $0, cells: cells) }
DispatchQueue.main.asyncAfter(deadline: .now() + duration) { exit(0) }
app.run()
