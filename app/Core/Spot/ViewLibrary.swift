import CryptoKit
import Foundation

public struct ViewLibrary: Sendable {
    public static let entry = "openspot_view_v1"
    static let libraryExtension = "view"
    private static let preludeName = "openspot-view.swift"
    private static let hashLength = 64
    static let sourceFault = "This view does not compile."
    static let toolsFault = "To draw a view, install the Command Line Tools: xcode-select --install"

    static let prelude = """
        public struct SpotFonts {
            public let title: Font
            public let detail: Font
            public let metric: Font
            public let value: Font
        }

        public struct SpotTheme {
            public struct Colors {
                public let ink: Color
                public let solid: Color
                public let onSolid: Color
                public let accent: Color
                public let good: Color
                public let warn: Color
                public let bad: Color
                public let secondary: Double
                public let fill: Double
                public let selected: Double
                public let track: Double
            }

            public struct Space {
                public let padding: CGFloat
                public let columnGap: CGFloat
                public let rowGap: CGFloat
                public let listRow: CGFloat
                public let listRowGap: CGFloat
                public let glyph: CGFloat
                public let cell: CGFloat
                public let gridWidth: CGFloat
            }

            public struct Radius {
                public let card: CGFloat
                public let media: CGFloat
                public let inner: CGFloat
            }

            public struct Fonts {
                public let title: Font
                public let body: Font
                public let detail: Font
                public let input: Font
            }

            public struct Motion {
                public let press: Double
                public let pressBounce: Double
            }

            public let color: Colors
            public let space: Space
            public let radius: Radius
            public let font: Fonts
            public let motion: Motion

            init(_ values: [String: Any]) {
                let number = { (key: String) in values[key] as? CGFloat ?? 0 }
                let strength = { (key: String) in Double(number(key)) }
                let color = { (key: String) in values[key] as? Color ?? .clear }
                let font = { (key: String) in values[key] as? Font ?? .body }
                self.color = Colors(
                    ink: color("ink"), solid: color("solid"), onSolid: color("onSolid"), accent: color("accent"), good: color("good"),
                    warn: color("warn"), bad: color("bad"), secondary: strength("secondary"), fill: strength("fill"),
                    selected: strength("selected"), track: strength("track")
                )
                space = Space(
                    padding: number("padding"), columnGap: number("columnGap"), rowGap: number("rowGap"), listRow: number("listRow"),
                    listRowGap: number("listRowGap"), glyph: number("glyph"), cell: number("cell"), gridWidth: number("gridWidth")
                )
                radius = Radius(card: number("card"), media: number("media"), inner: number("inner"))
                self.font = Fonts(title: font("title"), body: font("body"), detail: font("detail"), input: font("input"))
                motion = Motion(press: strength("press"), pressBounce: strength("pressBounce"))
            }
        }

        public enum SpotCard: String {
            case small, wide, square, strip, large
        }

        public struct SpotRow: Identifiable {
            let fields: [String]

            public var id: String { fields.count > 1 ? fields[1] : "" }

            public subscript(key: String) -> String? { all(key).last }

            public func all(_ key: String) -> [String] {
                stride(from: 0, to: fields.count - 1, by: 2).filter { fields[$0] == key }.map { fields[$0 + 1] }
            }
        }

        public struct SpotRows: RandomAccessCollection {
            let fields: [[String]]

            public var startIndex: Int { 0 }

            public var endIndex: Int { fields.count }

            public subscript(index: Int) -> SpotRow { SpotRow(fields: fields[index]) }
        }

        public struct SpotInput {
            public let size: CGSize
            public let card: SpotCard?
            public let inset: CGFloat
            public let corner: CGFloat
            public let ink: Color
            public let secondary: Double
            public let accent: Color
            public let font: SpotFonts
            public let theme: SpotTheme
            public let answers: Int
            public let columnGap: CGFloat
            public let rowGap: CGFloat
            public let columns: Int
            public let tipDelay: Duration
            public let rows: SpotRows
            public let isShown: Bool
            public let selection: String?
            let closer: () -> Void
            let timer: (Duration) -> Void
            let values: [String: [String]]
            let sender: (String) -> Void
            let cardMaker: (String) -> AnyView
            let cardSizer: (String) -> CGSize
            let sheetMaker: (String) -> AnyView
            let tipMaker: (String) -> AnyView
            let mediaMaker: (String) -> AnyView
            let cornerMaker: (String, String, String, @escaping () -> Void) -> AnyView

            init(values: [String: [String]], card: [String: Any], sender: @escaping (String) -> Void) {
                self.values = values
                self.sender = sender
                cardMaker = card["card"] as? (String) -> AnyView ?? { _ in AnyView(EmptyView()) }
                cardSizer = card["cardSize"] as? (String) -> CGSize ?? { _ in .zero }
                sheetMaker = card["sheet"] as? (String) -> AnyView ?? { _ in AnyView(EmptyView()) }
                tipMaker = card["tip"] as? (String) -> AnyView ?? { AnyView(Text($0)) }
                mediaMaker = card["media"] as? (String) -> AnyView ?? { _ in AnyView(EmptyView()) }
                cornerMaker = card["cornerButton"] as? (String, String, String, @escaping () -> Void) -> AnyView ?? { _, _, _, _ in AnyView(EmptyView()) }
                rows = SpotRows(fields: card["rows"] as? [[String]] ?? [])
                isShown = card["isShown"] as? Bool ?? true
                selection = card["selection"] as? String
                closer = card["close"] as? () -> Void ?? {}
                timer = card["bodyTime"] as? (Duration) -> Void ?? { _ in }
                columnGap = card["columnGap"] as? CGFloat ?? 11
                rowGap = card["rowGap"] as? CGFloat ?? 12
                columns = card["columns"] as? Int ?? 16
                tipDelay = card["tipDelay"] as? Duration ?? .milliseconds(500)
                size = card["size"] as? CGSize ?? .zero
                self.card = (card["cardName"] as? String).flatMap(SpotCard.init(rawValue:))
                answers = card["answers"] as? Int ?? 0
                inset = card["inset"] as? CGFloat ?? 13
                corner = card["corner"] as? CGFloat ?? 20
                ink = card["ink"] as? Color ?? .primary
                secondary = card["secondary"] as? Double ?? 0.7
                accent = card["accent"] as? Color ?? .accentColor
                font = SpotFonts(
                    title: card["title"] as? Font ?? .system(size: 13, weight: .medium),
                    detail: card["detail"] as? Font ?? .system(size: 11),
                    metric: card["metric"] as? Font ?? .system(size: 30, weight: .semibold, design: .rounded),
                    value: card["value"] as? Font ?? .system(size: 15, weight: .semibold, design: .rounded)
                )
                theme = SpotTheme(card["theme"] as? [String: Any] ?? [:])
            }

            public subscript(key: String) -> String? { values[key]?.last }

            public func all(_ key: String) -> [String] { values[key] ?? [] }

            public func send(_ value: String) { sender(value) }

            public func close() {
                if Thread.isMainThread { closer() } else { DispatchQueue.main.async(execute: closer) }
            }

            public func card(_ id: String) -> AnyView { cardMaker(id) }

            public func cardSize(_ id: String) -> CGSize { cardSizer(id) }

            public func sheet(_ id: String) -> AnyView { sheetMaker(id) }

            public func tip(_ text: String) -> AnyView { tipMaker(text) }

            public func media(_ source: String) -> AnyView { mediaMaker(source) }

            public func cornerButton(_ symbol: String, label: String, card id: String, action: @escaping () -> Void) -> AnyView { cornerMaker(symbol, label, id, action) }

            public func loop(period: Double, fill colors: [Color], path: @escaping (Double, CGRect) -> Path) -> some View {
                SpotLoop(period: period, size: size, values: values, isPlaying: isShown, look: .fill(colors), path: path)
            }

            public func loop(period: Double, stroke color: Color, width: CGFloat, path: @escaping (Double, CGRect) -> Path) -> some View {
                SpotLoop(period: period, size: size, values: values, isPlaying: isShown, look: .stroke(color, width), path: path)
            }
        }

        struct SpotLoop: NSViewRepresentable {
            enum Look: Equatable {
                case fill([Color])
                case stroke(Color, CGFloat)
            }

            let period: Double
            let size: CGSize
            let values: [String: [String]]
            let isPlaying: Bool
            let look: Look
            let path: (Double, CGRect) -> Path

            final class Stage: NSView {
                let shape = CAShapeLayer()
                let paint = CAGradientLayer()
                var key: (Double, CGSize, [String: [String]], Look)?

                override var isFlipped: Bool { true }

                init() {
                    super.init(frame: .zero)
                    wantsLayer = true
                    layer?.addSublayer(paint)
                }

                required init?(coder: NSCoder) { nil }

                func take(_ loop: SpotLoop) {
                    if key == nil || key?.0 != loop.period || key?.1 != loop.size || key?.2 != loop.values || key?.3 != loop.look {
                        key = (loop.period, loop.size, loop.values, loop.look)
                        build(loop)
                    }
                    play(loop.isPlaying)
                }

                private func build(_ loop: SpotLoop) {
                    let rect = CGRect(origin: .zero, size: loop.size)
                    let steps = max(2, Int(loop.period * 10))
                    let paths = (0...steps).map { loop.path(loop.period * Double($0) / Double(steps), rect).cgPath }
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    paint.frame = rect
                    shape.frame = rect
                    shape.removeAllAnimations()
                    shape.path = paths[0]
                    switch loop.look {
                    case .fill(let colors):
                        paint.isHidden = false
                        paint.colors = colors.map { NSColor($0).cgColor }
                        shape.fillColor = NSColor.black.cgColor
                        shape.strokeColor = nil
                        shape.removeFromSuperlayer()
                        paint.mask = shape
                    case .stroke(let color, let width):
                        paint.mask = nil
                        paint.isHidden = true
                        if shape.superlayer == nil { layer?.addSublayer(shape) }
                        shape.fillColor = nil
                        shape.strokeColor = NSColor(color).cgColor
                        shape.lineWidth = width
                    }
                    shape.speed = 1
                    shape.timeOffset = 0
                    shape.beginTime = 0
                    let wave = CAKeyframeAnimation(keyPath: "path")
                    wave.values = paths
                    wave.duration = loop.period
                    wave.repeatCount = .infinity
                    wave.isRemovedOnCompletion = false
                    shape.add(wave, forKey: "loop")
                    CATransaction.commit()
                }

                private func play(_ isPlaying: Bool) {
                    guard isPlaying != (shape.speed != 0) else { return }
                    if isPlaying {
                        let paused = shape.timeOffset
                        shape.speed = 1
                        shape.timeOffset = 0
                        shape.beginTime = 0
                        shape.beginTime = shape.convertTime(CACurrentMediaTime(), from: nil) - paused
                    } else {
                        shape.timeOffset = shape.convertTime(CACurrentMediaTime(), from: nil)
                        shape.speed = 0
                    }
                }
            }

            func makeNSView(context: Context) -> Stage { Stage() }

            func updateNSView(_ stage: Stage, context: Context) { stage.take(self) }
        }

        public struct SpotMetric: View {
            let spot: SpotInput
            let value: String
            let detail: String
            let mark: String?
            let isOnFill: Bool

            public init(_ spot: SpotInput, value: String, detail: String = "", mark: String? = nil, onFill: Bool = false) {
                self.spot = spot
                self.value = value
                self.detail = detail
                self.mark = mark
                isOnFill = onFill
            }

            public var body: some View {
                Group {
                    switch shape {
                    case .small:
                        VStack(spacing: -1) {
                            number(.system(size: 20, weight: .semibold, design: .rounded))
                            note(withDetail: true, font: .system(size: 8)).multilineTextAlignment(.center)
                        }
                        .padding(spot.inset / 2)
                    case .wide, .strip:
                        ViewThatFits(in: .horizontal) {
                            line(withDetail: true)
                            line(withDetail: false)
                        }
                        .padding(.horizontal, spot.inset)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                    default:
                        VStack(alignment: .leading, spacing: 2) {
                            number(spot.font.metric)
                            note(withDetail: true, font: spot.font.detail)
                        }
                        .padding(spot.inset + 4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
                .foregroundStyle(isOnFill ? .white : spot.ink)
            }

            private var shape: SpotCard {
                spot.card ?? (spot.size.height >= 100 ? .large : spot.size.width < 100 ? .small : .strip)
            }

            private var detailOpacity: Double { isOnFill ? 1 : spot.secondary }

            private func number(_ font: Font) -> some View {
                Text(value).font(font).lineLimit(1).minimumScaleFactor(0.6).layoutPriority(1)
            }

            private func line(withDetail: Bool) -> some View {
                HStack(alignment: .center, spacing: 6) {
                    number(spot.font.metric).fixedSize()
                    note(withDetail: withDetail, font: spot.font.detail).fixedSize()
                }
            }

            private func note(withDetail: Bool, font: Font) -> some View {
                HStack(spacing: 3) {
                    if withDetail && !detail.isEmpty {
                        Text(detail)
                    }
                    if let mark {
                        Image(systemName: mark)
                    }
                }
                .font(font)
                .opacity(detailOpacity)
            }
        }

        extension SpotView: DynamicProperty {}

        struct SpotTimedView: View {
            var view: SpotView
            let timer: (Duration) -> Void

            var body: some View {
                let start = ContinuousClock.now
                let content = view.body
                timer(ContinuousClock.now - start)
                return content
            }
        }

        @_cdecl("\(entry)")
        public func openspotViewEntry() -> UnsafeMutableRawPointer {
            let make: ([String: [String]], [String: Any], @escaping (String) -> Void) -> AnyView = { values, card, send in
                let input = SpotInput(values: values, card: card, sender: send)
                return AnyView(SpotTimedView(view: SpotView(spot: input), timer: input.timer))
            }
            return Unmanaged.passRetained(make as AnyObject).toOpaque()
        }

        """

    private let cache: URL
    private let tools: URL

    public init(cache: URL, tools: URL = URL(fileURLWithPath: "/usr/bin", isDirectory: true)) {
        self.cache = cache
        self.tools = tools
    }

    public static func standard(cache: URL = AppCache.folder()) -> ViewLibrary {
        ViewLibrary(cache: cache.appendingPathComponent("views", isDirectory: true))
    }

    static func path(beside source: String, text: Data) -> String {
        (source as NSString).deletingPathExtension + "." + name(of: text) + "." + libraryExtension
    }

    static func isLibrary(_ path: String) -> Bool {
        (path as NSString).pathExtension == libraryExtension
    }

    static func isLibrary(_ path: String, of source: String) -> Bool {
        let stem = (source as NSString).deletingPathExtension + "."
        guard isLibrary(path), path.hasPrefix(stem) else { return false }
        let hash = (path.dropFirst(stem.count) as NSString).deletingPathExtension
        return hash.count == hashLength && hash.allSatisfy(\.isHexDigit)
    }

    public func library(of source: URL) async throws -> URL {
        guard let text = try? Data(contentsOf: source) else {
            throw SpotError.fault("Openspot cannot find the view \(source.lastPathComponent).")
        }
        return try await library(of: source, text: text)
    }

    func kept(of source: URL, text: Data) -> URL? {
        let carried = URL(fileURLWithPath: Self.path(beside: source.path, text: text))
        if FileManager.default.fileExists(atPath: carried.path) { return carried }
        let built = cache.appendingPathComponent("\(Self.name(of: text)).dylib")
        return FileManager.default.fileExists(atPath: built.path) ? built : nil
    }

    func library(of source: URL, text: Data) async throws -> URL {
        if let kept = kept(of: source, text: text) { return kept }
        let name = Self.name(of: text)
        let built = cache.appendingPathComponent("\(name).dylib")
        let data = try await build(source: text, named: source.lastPathComponent, kinds: [Self.thisMac])
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let part = cache.appendingPathComponent("\(name).\(UUID().uuidString).part")
        try data.write(to: part)
        _ = try FileManager.default.replaceItemAt(built, withItemAt: part)
        return built
    }

    public func buildViews(under folder: URL) async throws -> [URL] {
        var built: [URL] = []
        let scripts = (FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? [])
            .filter { FileManager.default.isExecutableFile(atPath: $0.path) && !$0.hasDirectoryPath }
            .sorted { $0.path < $1.path }
        for script in scripts {
            guard let text = try? String(contentsOf: script, encoding: .utf8), let name = SpotHeader(text: text).block.value("view"), !name.hasPrefix("/") else { continue }
            let source = script.deletingLastPathComponent().appendingPathComponent(name)
            guard let data = try? Data(contentsOf: source) else { continue }
            let library = URL(fileURLWithPath: Self.path(beside: source.path, text: data))
            try await build(source: data, named: name, kinds: SwiftBuild.kinds).write(to: library)
            let folder = source.deletingLastPathComponent()
            for old in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where old != library.lastPathComponent && Self.isLibrary(old, of: source.lastPathComponent) {
                try FileManager.default.removeItem(at: folder.appendingPathComponent(old))
            }
            built.append(library)
        }
        return built
    }

    public func build(source: Data, named name: String, kinds: [String]) async throws -> Data {
        let module = "View\(Self.name(of: source).prefix(16))"
        let flags = ["-emit-library", "-parse-as-library", "-O", "-module-name", module, "-Xfrontend", "-import-module", "-Xfrontend", "SwiftUI", "-Xfrontend", "-import-module", "-Xfrontend", "AppKit"]
        let files = [SwiftBuild.File(name: Self.preludeName, data: Data(Self.prelude.utf8)), SwiftBuild.File(name: name, data: source)]
        return try await SwiftBuild(tools: tools).output(of: files, flags: flags, kinds: kinds, toolsFault: Self.toolsFault, fault: Self.sourceFault)
    }

    private static var thisMac: String {
        #if arch(arm64)
        "arm64"
        #else
        "x86_64"
        #endif
    }

    static func name(of source: Data) -> String {
        SHA256.hash(data: Data(prelude.utf8) + source).map { String(format: "%02x", $0) }.joined()
    }
}
