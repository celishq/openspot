import CoreGraphics
import Foundation

extension BackdropFade {
    public struct Slices: Equatable, Sendable {
        public let columns: [Int]
        public let rows: [Int]
    }

    public func picture(of area: CGRect, size: CGSize, scale: CGFloat) -> CGContext? {
        guard let context = CGContext(
            data: nil, width: Self.pixels(size.width, scale), height: Self.pixels(size.height, scale),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.setBlendMode(.copy)
        for ring in rings(in: area) {
            let frame = CGRect(x: ring.rect.minX, y: size.height - ring.rect.maxY, width: ring.rect.width, height: ring.rect.height)
            context.setFillColor(CGColor(gray: 0, alpha: ring.strength))
            context.addPath(CGPath(roundedRect: frame, cornerWidth: ring.corner, cornerHeight: ring.corner, transform: nil))
            context.fillPath()
        }
        return context
    }

    public func slices(from drawn: CGRect, to area: CGRect, size: CGSize, scale: CGFloat) -> Slices? {
        let from = rings(in: drawn)
        let to = rings(in: area)
        guard from.map(\.corner) == to.map(\.corner),
              let fromColumns = Self.band(of: from, start: \.minX, end: \.maxX), let toColumns = Self.band(of: to, start: \.minX, end: \.maxX),
              let fromRows = Self.band(of: from, start: \.minY, end: \.maxY), let toRows = Self.band(of: to, start: \.minY, end: \.maxY) else { return nil }
        let height = Self.pixels(size.height, scale)
        let columns = Self.axis(
            count: Self.pixels(size.width, scale), offset: 0, scale: scale,
            band: toColumns, middle: (fromColumns.lowerBound + fromColumns.upperBound) / 2, before: area.minX - drawn.minX, after: area.maxX - drawn.maxX
        )
        let rows = Self.axis(
            count: height, offset: CGFloat(height) - size.height * scale, scale: scale,
            band: toRows, middle: (fromRows.lowerBound + fromRows.upperBound) / 2, before: area.minY - drawn.minY, after: area.maxY - drawn.maxY
        )
        return Slices(columns: columns, rows: rows)
    }

    public static func image(of picture: CGContext, slices: Slices) -> CGImage? {
        guard let source = picture.data, let space = picture.colorSpace, picture.bitsPerPixel == 32,
              slices.columns.count == picture.width, slices.rows.count == picture.height else { return nil }
        let row = picture.bytesPerRow
        var pixels = Data(count: row * picture.height)
        pixels.withUnsafeMutableBytes { target in
            guard let start = target.baseAddress else { return }
            var built: (source: Int, target: Int)?
            for (line, from) in slices.rows.enumerated() {
                let destination = start + line * row
                if let built, built.source == from {
                    destination.copyMemory(from: start + built.target * row, byteCount: row)
                    continue
                }
                copy(row: source + from * row, into: destination, columns: slices.columns)
                built = (from, line)
            }
        }
        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        return CGImage(
            width: picture.width, height: picture.height, bitsPerComponent: picture.bitsPerComponent, bitsPerPixel: picture.bitsPerPixel, bytesPerRow: row,
            space: space, bitmapInfo: picture.bitmapInfo, provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    private static func copy(row source: UnsafeRawPointer, into target: UnsafeMutableRawPointer, columns: [Int]) {
        var column = 0
        while column < columns.count {
            var end = column + 1
            while end < columns.count, columns[end] == columns[end - 1] + 1 { end += 1 }
            if end - column > 1 {
                (target + column * 4).copyMemory(from: source + columns[column] * 4, byteCount: (end - column) * 4)
            } else {
                end = column + 1
                while end < columns.count, columns[end] == columns[column] { end += 1 }
                for place in column..<end { (target + place * 4).copyMemory(from: source + columns[column] * 4, byteCount: 4) }
            }
            column = end
        }
    }

    private static func pixels(_ length: CGFloat, _ scale: CGFloat) -> Int {
        Int((length * scale).rounded(.up))
    }

    private static func band(of rings: [Ring], start: KeyPath<CGRect, CGFloat>, end: KeyPath<CGRect, CGFloat>) -> ClosedRange<CGFloat>? {
        guard let first = rings.map({ $0.rect[keyPath: start] + $0.corner }).max(), let last = rings.map({ $0.rect[keyPath: end] - $0.corner }).min(),
              first < last else { return nil }
        return first...last
    }

    private static func axis(count: Int, offset: CGFloat, scale: CGFloat, band: ClosedRange<CGFloat>, middle: CGFloat, before: CGFloat, after: CGFloat) -> [Int] {
        (0..<count).map { index in
            let place = (CGFloat(index) + 0.5 - offset) / scale
            let source = place < band.lowerBound ? place - before : place > band.upperBound ? place - after : middle
            return min(max(Int((source * scale + offset - 0.5).rounded()), 0), count - 1)
        }
    }
}
