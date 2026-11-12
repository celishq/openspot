import AppKit
import Carbon
import ImageIO
import QuartzCore

/// How light falls on a piece: one plain colour, paper that bends, or polished foil.
enum Finish: String, CaseIterable { case flat, paper, foil }

/// The outline of one piece.
enum Shape: String, CaseIterable {
    case rect, square, strip, dot, bead, flag, arc, heart, star, streamer

    var size: CGSize {
        switch self {
        case .rect: return CGSize(width: 16, height: 9)
        case .square: return CGSize(width: 11, height: 11)
        case .strip: return CGSize(width: 22, height: 5)
        case .dot: return CGSize(width: 8, height: 8)
        case .bead: return CGSize(width: 15, height: 15)
        case .flag: return CGSize(width: 22, height: 16)
        case .arc: return CGSize(width: 42, height: 20)
        case .heart: return CGSize(width: 16, height: 15)
        case .star: return CGSize(width: 16, height: 16)
        case .streamer: return CGSize(width: 38, height: 150)
        }
    }

    /// The outline in a box of `size`, to fill.
    func path(in box: CGRect) -> CGPath {
        func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: box.minX + x * box.width, y: box.minY + y * box.height) }
        switch self {
        case .rect, .square, .strip, .streamer:
            return CGPath(rect: box, transform: nil)
        case .dot, .bead:
            return CGPath(ellipseIn: box.insetBy(dx: 0.5, dy: 0.5), transform: nil)
        case .flag:
            let path = CGMutablePath()
            path.addLines(between: [at(0.05, 0.06), at(0.95, 0.19), at(0.82, 0.94), at(0.14, 0.88)])
            path.closeSubpath()
            return path
        case .arc:
            let radius = box.width * 0.62
            let line = CGMutablePath()
            line.addArc(center: CGPoint(x: box.midX, y: box.maxY - 3 - radius), radius: radius, startAngle: .pi * 0.28, endAngle: .pi * 0.72, clockwise: false)
            return line.copy(strokingWithWidth: 8, lineCap: .butt, lineJoin: .round, miterLimit: 4)
        case .heart:
            let path = CGMutablePath()
            path.move(to: at(0.5, 0.02))
            path.addCurve(to: at(0.02, 0.62), control1: at(0.36, 0.18), control2: at(0.02, 0.38))
            path.addCurve(to: at(0.5, 0.78), control1: at(0.02, 0.96), control2: at(0.42, 1.04))
            path.addCurve(to: at(0.98, 0.62), control1: at(0.58, 1.04), control2: at(0.98, 0.96))
            path.addCurve(to: at(0.5, 0.02), control1: at(0.98, 0.38), control2: at(0.64, 0.18))
            path.closeSubpath()
            return path
        case .star:
            let path = CGMutablePath()
            let points = (0..<10).map { index -> CGPoint in
                let angle = .pi / 2 + Double(index) * .pi / 5
                let reach = index % 2 == 0 ? 0.5 : 0.21
                return at(0.5 + reach * cos(angle), 0.47 + reach * sin(angle))
            }
            path.addLines(between: points)
            path.closeSubpath()
            return path
        }
    }
}

/// What one piece is: a shape tinted with a colour, or a glyph such as an emoji drawn as it is.
enum Kind: Hashable {
    case shape(Shape)
    case glyph(String)

    var size: CGSize {
        switch self {
        case .shape(let shape): return shape.size
        case .glyph: return CGSize(width: 26, height: 26)
        }
    }
}

/// A look as a look file writes it: its colours, its pieces, its finish, and how many, how fast and how large they fall.
struct Look {
    var title = ""
    var colors: [(NSColor, Double)] = []
    var kinds: [(Kind, Double)] = []
    var finish = Finish.flat
    var amount = 1.0
    var speed = 1.0
    var size = 1.0

    static let keys = ["title", "color", "shape", "glyph", "finish", "amount", "speed", "size"]

    /// The look in the file at `path`, and a line for each fault that stops it from playing.
    static func read(_ path: String) -> (Look, [String]) {
        var look = Look(title: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return (look, ["Openspot cannot read \(path)."])
        }
        var faults: [String] = []
        for (index, raw) in text.components(separatedBy: .newlines).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let at = "Line \(index + 1)"
            guard let equals = line.firstIndex(of: "=") else {
                faults.append("\(at): `\(line)` has no `=`. Write each line as `key=value`.")
                continue
            }
            let key = line[..<equals].trimmingCharacters(in: .whitespaces)
            let (value, share) = weighed(line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces))
            switch key {
            case "title":
                look.title = value
            case "color":
                if let color = hex(value) { look.colors.append((color, share)) } else {
                    faults.append("\(at): `\(value)` is not a colour. Write it as `#RRGGBB`, such as `#FF4D6D`.")
                }
            case "shape":
                if let shape = Shape(rawValue: value) { look.kinds.append((.shape(shape), share)) } else {
                    faults.append("\(at): there is no shape `\(value)`. The shapes are \(Shape.allCases.map { "`\($0.rawValue)`" }.joined(separator: ", ")).")
                }
            case "glyph":
                if !value.isEmpty, value.count <= 3 { look.kinds.append((.glyph(value), share)) } else {
                    faults.append("\(at): a glyph is one to three characters, such as `💖`.")
                }
            case "finish":
                if let finish = Finish(rawValue: value) { look.finish = finish } else {
                    faults.append("\(at): the finish is `flat`, `paper` or `foil`.")
                }
            case "amount", "speed", "size":
                let range: ClosedRange<Double> = key == "speed" ? 0.5...2 : key == "amount" ? 0.2...3 : 0.5...3
                if let number = Double(value), range.contains(number) {
                    if key == "amount" { look.amount = number } else if key == "speed" { look.speed = number } else { look.size = number }
                } else {
                    faults.append("\(at): `\(key)` is a number from \(range.lowerBound) to \(range.upperBound).")
                }
            default:
                faults.append("\(at): there is no key `\(key)`. The keys are \(keys.map { "`\($0)`" }.joined(separator: ", ")).")
            }
        }
        if look.kinds.isEmpty { faults.append("The look has no pieces. Add a `shape=` or a `glyph=` line.") }
        if look.kinds.contains(where: { if case .shape = $0.0 { return true } else { return false } }) && look.colors.isEmpty {
            faults.append("Its shapes have no colour. Add a `color=` line.")
        }
        return (look, faults)
    }

    /// A value and its share, from `value` or `value share`, such as `heart 2`.
    static func weighed(_ text: String) -> (String, Double) {
        let parts = text.split(separator: " ")
        if parts.count >= 2, let share = Double(parts[parts.count - 1]), share > 0 {
            return (parts.dropLast().joined(separator: " "), share)
        }
        return (text, 1)
    }

    static func hex(_ text: String) -> NSColor? {
        let digits = text.hasPrefix("#") ? String(text.dropFirst()) : text
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return nil }
        return rgb(value)
    }
}

func rgb(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

/// The colour mixed toward white by `amount`, or darkened when `amount` is negative, a yellow toward amber.
func shade(_ color: NSColor, _ amount: CGFloat) -> CGColor {
    let amount = max(-1, min(1, amount))
    guard amount < 0, let color = color.usingColorSpace(.sRGB) else {
        return (color.blended(withFraction: amount, of: .white) ?? color).cgColor
    }
    let dark = -amount
    let warm = color.hueComponent > 0.08 && color.hueComponent < 0.2 && color.saturationComponent > 0.3
    let hue = warm ? color.hueComponent - 0.05 * dark : color.hueComponent
    let saturation = min(1, color.saturationComponent * (1 + 0.25 * dark))
    return NSColor(hue: hue, saturation: saturation, brightness: color.brightnessComponent * (1 - 0.8 * dark), alpha: 1).cgColor
}

/// The pictures of one piece through a full turn, one for each step.
func frames(_ kind: Kind, _ color: NSColor, finish: Finish, scale: CGFloat) -> [CGImage] {
    let steps = 12
    let size = kind.size
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let bend = Double.random(in: 0..<(2 * .pi))
    return (0..<steps).compactMap { step in
        let turn = Double(step) / Double(steps) * 2 * .pi
        guard let context = CGContext(data: nil, width: Int(ceil(size.width * scale)), height: Int(ceil(size.height * scale)), bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.scaleBy(x: scale, y: scale)
        let box = CGRect(origin: .zero, size: size)
        let shape: Shape
        switch kind {
        case .glyph(let text):
            glyph(context, box: box, text: text, color: color)
            return context.makeImage()
        case .shape(.streamer):
            streamer(context, box: box, color: color, finish: finish, roll: turn, bend: bend)
            return context.makeImage()
        case .shape(let other):
            shape = other
        }
        context.addPath(shape.path(in: box))
        context.clip()
        let facing = cos(turn)
        switch finish {
        case .flat:
            let amount = facing >= 0 ? -0.18 * (1 - facing) : -0.2 - 0.12 * (1 + facing)
            context.setFillColor(shade(color, CGFloat(amount)))
            context.fill(box)
        case .paper:
            let dim = CGFloat(facing >= 0 ? -0.1 * (1 - facing) : -0.14 - 0.1 * (1 + facing))
            let gradient = CGGradient(colorsSpace: space, colors: [shade(color, 0.32 + dim), shade(color, dim), shade(color, -0.16 + dim)] as CFArray, locations: [0, 0.55, 1])!
            context.drawLinearGradient(gradient, start: CGPoint(x: box.minX, y: box.maxY), end: CGPoint(x: box.maxX, y: box.minY), options: [])
        case .foil:
            let glint = pow(max(0, cos(turn - 0.6)), 8)
            let light = CGFloat(turn / (2 * .pi))
            let stops: [(CGFloat, CGColor)] = [
                (0, shade(color, -0.62)),
                (max(0.01, light - 0.26), shade(color, -0.12)),
                (max(0.02, min(0.98, light)), shade(color, 0.6 + 0.38 * glint)),
                (min(0.99, light + 0.26), shade(color, -0.08)),
                (1, shade(color, -0.6)),
            ]
            let gradient = CGGradient(colorsSpace: space, colors: stops.map(\.1) as CFArray, locations: stops.map(\.0))!
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        return context.makeImage()
    }
}

/// Draws a glyph, such as an emoji, centred in its box and as large as it fits, as an emoji where it has one and in `color`
/// where it has none.
func glyph(_ context: CGContext, box: CGRect, text: String, color: NSColor) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
    let shown = text.unicodeScalars.count == 1 ? text + "\u{FE0F}" : text
    let words = NSAttributedString(string: shown, attributes: [.font: NSFont.systemFont(ofSize: box.height * 0.8), .foregroundColor: color])
    let bounds = words.size()
    words.draw(at: CGPoint(x: box.midX - bounds.width / 2, y: box.midY - bounds.height / 2))
    NSGraphicsContext.restoreGraphicsState()
}

/// Draws a long ribbon that hangs in a loose wave and twists about its length, rolled on by `roll`.
func streamer(_ context: CGContext, box: CGRect, color: NSColor, finish: Finish, roll: Double, bend: Double) {
    let width = 9.0
    let sway = Double(box.width) / 2 - width / 2 - 1
    let twists = 1.9
    let count = 160
    func center(_ t: Double) -> CGPoint {
        CGPoint(x: Double(box.midX) + sway * sin(2 * .pi * 1.1 * t + bend) * (0.55 + 0.45 * t), y: 2 + t * (Double(box.height) - 4))
    }
    for index in 0..<count {
        let t0 = Double(index) / Double(count)
        let t1 = Double(index + 1) / Double(count)
        let a = center(t0)
        let b = center(t1)
        let length = max(0.001, hypot(b.x - a.x, b.y - a.y))
        let normal = CGPoint(x: -(b.y - a.y) / length, y: (b.x - a.x) / length)
        let twist0 = 2 * .pi * twists * t0 + roll
        let twist1 = 2 * .pi * twists * t1 + roll
        let half0 = width / 2 * cos(twist0)
        let half1 = width / 2 * cos(twist1)
        let face = cos((twist0 + twist1) / 2)
        let amount: CGFloat
        if finish == .foil {
            amount = face >= 0 ? CGFloat(-0.15 + 0.85 * pow(face, 3)) : CGFloat(-0.2 - 0.45 * abs(face))
        } else {
            amount = face >= 0 ? CGFloat(0.2 * face) : CGFloat(-0.15 - 0.2 * abs(face))
        }
        context.setFillColor(shade(color, amount))
        context.beginPath()
        context.move(to: CGPoint(x: a.x - normal.x * half0, y: a.y - normal.y * half0))
        context.addLine(to: CGPoint(x: a.x + normal.x * half0, y: a.y + normal.y * half0))
        context.addLine(to: CGPoint(x: b.x + normal.x * half1 * 1.02, y: b.y + normal.y * half1 * 1.02 + 0.3))
        context.addLine(to: CGPoint(x: b.x - normal.x * half1 * 1.02, y: b.y - normal.y * half1 * 1.02 + 0.3))
        context.closePath()
        context.fillPath()
    }
}

/// One piece of confetti and the layer that shows it.
final class Piece {
    let layer = CALayer()
    let frames: [CGImage]
    let kind: Kind
    var position: CGPoint
    var velocity: CGVector
    let drag: Double
    let size: CGFloat
    var angle: Double
    let spin: Double
    var turn: Double
    let turnRate: Double
    let sway: Double
    let swayRate: Double
    let phase: Double
    var step = -1

    init(frames: [CGImage], kind: Kind, position: CGPoint, velocity: CGVector, drag: Double, size: CGFloat) {
        self.frames = frames
        self.kind = kind
        self.position = position
        self.velocity = velocity
        self.drag = drag
        self.size = size
        let streamer = kind == .shape(.streamer)
        angle = streamer ? .random(in: -0.35...0.35) : .random(in: 0..<(2 * .pi))
        spin = streamer ? 0 : .random(in: -3...3)
        turn = .random(in: 0..<(2 * .pi))
        turnRate = (streamer ? .random(in: 5...9) : .random(in: 4...12)) * (Bool.random() ? 1 : -1)
        sway = .random(in: 8...26)
        swayRate = .random(in: 1.6...3.4)
        phase = .random(in: 0..<(2 * .pi))
    }
}

/// The confetti over one area, from its first piece until the last one leaves at the bottom.
final class Shower: NSObject {
    let root = CALayer()
    let bounds: CGRect
    let gravity: Double
    var pieces: [Piece] = []
    var time = 0.0
    var last: CFTimeInterval?
    var link: CADisplayLink?
    var finished: (() -> Void)?

    init(look: Look, bounds: CGRect, scale: CGFloat) {
        self.bounds = bounds
        gravity = Double(bounds.height) * 2.45
        super.init()
        root.frame = bounds
        var cache: [String: [CGImage]] = [:]
        let count = Int(Double(bounds.width) * 0.27 * look.amount)
        for index in 0..<count {
            let kind = Shower.pick(look.kinds)
            let color = look.colors.isEmpty ? NSColor.white : Shower.pick(look.colors)
            let key = "\(kind)-\(color)"
            let detail = kind == .shape(.streamer) ? scale * 1.5 : scale * 3
            let images = cache[key] ?? frames(kind, color, finish: look.finish, scale: detail)
            cache[key] = images
            let piece = fall(images, kind, look: look, index: index, count: count)
            piece.layer.bounds = CGRect(origin: .zero, size: kind.size)
            piece.layer.contentsScale = detail
            piece.layer.isHidden = true
            pieces.append(piece)
            root.addSublayer(piece.layer)
        }
    }

    static func pick<T>(_ shares: [(T, Double)]) -> T {
        var roll = Double.random(in: 0..<shares.reduce(0) { $0 + $1.1 })
        for (item, share) in shares {
            roll -= share
            if roll < 0 { return item }
        }
        return shares[0].0
    }

    /// A piece that enters at the top edge, at any point of its width, and falls through the whole height, a heavy piece
    /// from higher up and faster than a light one.
    func fall(_ images: [CGImage], _ kind: Kind, look: Look, index: Int, count: Int) -> Piece {
        let height = Double(bounds.height)
        let weight = Double.random(in: 0...1)
        let size = CGFloat(look.size) * CGFloat(kind == .shape(.streamer) ? .random(in: 0.8...1.15) : .random(in: 0.65...1.35))
        let terminal = height * (kind == .shape(.streamer) ? 0.62 : 0.73) * (0.6 + 0.75 * weight) * look.speed
        let x = Double(bounds.width) * (Double(index) + .random(in: 0..<1)) / Double(count)
        let y = height + Double(kind.size.height) * Double(size) + .random(in: 0...height * 0.5) * (0.35 + 0.65 * weight)
        let launch = CGVector(dx: .random(in: -0.16...0.16) * height, dy: -terminal * .random(in: 1.1...1.7))
        return Piece(frames: images, kind: kind, position: CGPoint(x: x, y: y), velocity: launch, drag: gravity / terminal, size: size)
    }

    func start(in view: NSView) {
        link = view.displayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
    }

    @objc func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = min(1.0 / 30, now - (last ?? now))
        last = now
        if !advance(dt) {
            link.invalidate()
            finished?()
        }
    }

    /// Moves each piece on by `dt` seconds, and says whether any piece is still in view.
    @discardableResult
    func advance(_ dt: Double) -> Bool {
        time += dt
        var alive = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for piece in pieces {
            let keep = exp(-piece.drag * dt)
            piece.velocity.dx *= keep
            piece.velocity.dy = piece.velocity.dy * keep - gravity * dt * keep
            piece.angle += piece.spin * dt
            piece.turn += piece.turnRate * dt
            let swing = piece.sway * piece.swayRate * cos(piece.swayRate * time + piece.phase)
            piece.position.x += (piece.velocity.dx + swing) * dt
            piece.position.y += piece.velocity.dy * dt
            let visible = piece.position.y > -Double(piece.kind.size.height) * Double(piece.size)
            piece.layer.isHidden = !visible
            guard visible else { continue }
            alive = true
            let turn = piece.turn.truncatingRemainder(dividingBy: 2 * .pi) + (piece.turn < 0 ? 2 * .pi : 0)
            let step = min(piece.frames.count - 1, Int(turn / (2 * .pi) * Double(piece.frames.count)))
            if step != piece.step {
                piece.step = step
                piece.layer.contents = piece.frames[step]
            }
            var transform: CATransform3D
            switch piece.kind {
            case .shape(.streamer):
                transform = CATransform3DMakeRotation(CGFloat(piece.angle + 0.2 * sin(piece.swayRate * time + piece.phase)), 0, 0, 1)
                transform = CATransform3DScale(transform, piece.size, piece.size, 1)
            case .glyph:
                transform = CATransform3DMakeRotation(CGFloat(piece.angle * 0.3), 0, 0, 1)
                transform = CATransform3DScale(transform, piece.size * CGFloat(max(0.3, abs(cos(turn * 0.5)))), piece.size, 1)
            case .shape:
                transform = CATransform3DMakeRotation(CGFloat(piece.angle), 0, 0, 1)
                transform = CATransform3DScale(transform, piece.size, piece.size * CGFloat(max(0.12, abs(cos(turn)))), 1)
            }
            piece.layer.transform = transform
            piece.layer.position = piece.position
        }
        CATransaction.commit()
        return alive && time < 6
    }
}

/// A clear window over one screen, which takes no click and no focus.
func window(on screen: NSScreen, shower: Shower) -> NSWindow {
    let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.level = .screenSaver
    window.ignoresMouseEvents = true
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    let view = NSView(frame: CGRect(origin: .zero, size: screen.frame.size))
    view.wantsLayer = true
    view.layer?.addSublayer(shower.root)
    window.contentView = view
    window.orderFrontRegardless()
    shower.start(in: view)
    return window
}

/// Draws the shower as it looks `seconds` after it starts, over a pale ground, into a PNG at `path`, with no window.
func still(_ look: Look, seconds: Double, path: String) -> Bool {
    let size = CGSize(width: 1512, height: 982)
    let shower = Shower(look: look, bounds: CGRect(origin: .zero, size: size), scale: 1)
    for _ in 0..<Int(seconds * 120) { shower.advance(1.0 / 120) }
    let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(rgb(0xF3F4F7).cgColor)
    context.fill(CGRect(origin: .zero, size: size))
    shower.root.render(in: context)
    guard let image = context.makeImage(), let file = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, "public.png" as CFString, 1, nil) else { return false }
    CGImageDestinationAddImage(file, image, nil)
    return CGImageDestinationFinalize(file)
}

/// The windows of each shower that plays now, kept until its last piece leaves.
var playing: [ObjectIdentifier: NSWindow] = [:]

/// Plays the look once on each screen, and calls `done` when every screen is clear.
func play(_ look: Look, done: @escaping () -> Void) {
    var left = NSScreen.screens.count
    for screen in NSScreen.screens {
        let shower = Shower(look: look, bounds: CGRect(origin: .zero, size: screen.frame.size), scale: screen.backingScaleFactor)
        let id = ObjectIdentifier(shower)
        shower.finished = {
            playing[id]?.orderOut(nil)
            playing[id] = nil
            left -= 1
            if left == 0 { done() }
        }
        playing[id] = window(on: screen, shower: shower)
    }
}

/// The key code and the modifiers of a key such as `ctrl+option+c`, as Openspot's key recorder writes it.
func hotKey(_ text: String) -> (UInt32, UInt32)? {
    let codes: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
        "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27,
        "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "return": 36, "l": 37, "j": 38, "'": 39,
        "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "backspace": 51, "delete": 51, "escape": 53, "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
        "f11": 103, "f12": 111,
    ]
    let flags: [String: Int] = ["cmd": cmdKey, "command": cmdKey, "ctrl": controlKey, "control": controlKey, "option": optionKey, "opt": optionKey, "alt": optionKey, "shift": shiftKey]
    let parts = text.lowercased().split(separator: "+").map(String.init)
    guard let last = parts.last, let code = codes[last] else { return nil }
    var modifiers = 0
    for part in parts.dropLast() {
        guard let flag = flags[part] else { return nil }
        modifiers |= flag
    }
    return modifiers == 0 ? nil : (code, UInt32(modifiers))
}

/// The look the person picked, from the data folder's `default` file and its `looks` folder, else from the built-in looks.
func chosen(data: String, builtIn: String) -> Look? {
    let id = (try? String(contentsOfFile: data + "/default", encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let name = id.isEmpty ? "colorful" : id
    let mine = data + "/looks/" + name + ".look"
    let path = FileManager.default.fileExists(atPath: mine) ? mine : builtIn + "/" + name + ".look"
    let (look, faults) = Look.read(path)
    return faults.isEmpty ? look : Look.read(builtIn + "/colorful.look").0
}

var listening: (data: String, builtIn: String) = ("", "")

/// Waits for the key in the background, and plays the picked look each time it is pressed.
func listen(key: String, data: String, builtIn: String) -> Never {
    guard let (code, modifiers) = hotKey(key) else {
        FileHandle.standardError.write("Openspot cannot use the key \(key). Hold cmd, ctrl or option with a letter, a digit or a key such as space.\n".data(using: .utf8)!)
        exit(2)
    }
    listening = (data, builtIn)
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
        if let look = chosen(data: listening.data, builtIn: listening.builtIn) { play(look) {} }
        return noErr
    }, 1, &spec, nil, nil)
    var reference: EventHotKeyRef?
    let status = RegisterEventHotKey(code, modifiers, EventHotKeyID(signature: OSType(0x434E_4654), id: 1), GetApplicationEventTarget(), 0, &reference)
    guard status == noErr else {
        FileHandle.standardError.write("Another app already uses \(key). Pick another key.\n".data(using: .utf8)!)
        exit(3)
    }
    app.run()
    exit(0)
}

let usage = """
    confetti <file.look>                             Plays the look on each screen.
    confetti check <file.look>                       Says whether the look file can play, or what to fix.
    confetti still <file.look> <seconds> <file.png>  Draws the look as it is that many seconds in.
    confetti listen <key> <data folder> <looks folder>  Plays the picked look each time the key is pressed.
    """
let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? ""
if command == "listen" {
    guard arguments.count == 4 else {
        print(usage)
        exit(2)
    }
    listen(key: arguments[1], data: arguments[2], builtIn: arguments[3])
}
let path = command == "check" || command == "still" ? arguments.dropFirst().first : arguments.first
guard let path, !path.isEmpty else {
    print(usage)
    exit(2)
}
let (look, faults) = Look.read(path)
if !faults.isEmpty {
    FileHandle.standardError.write((faults.joined(separator: "\n") + "\n").data(using: .utf8)!)
    exit(1)
}
if command == "check" {
    print("\(look.title) can play: \(look.colors.count) colours, \(look.kinds.count) kinds of piece, a \(look.finish.rawValue) finish.")
    exit(0)
}
if command == "still" {
    guard arguments.count == 4, let seconds = Double(arguments[2]) else {
        print(usage)
        exit(2)
    }
    exit(still(look, seconds: seconds, path: arguments[3]) ? 0 : 1)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
play(look) { exit(0) }
app.run()
