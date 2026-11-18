import AppKit
import OpenspotCore
import SwiftUI

enum SpotType {
    struct Faces {
        let sizes: Theme.TypeSizes
        let title: Font
        let body: Font
        let detail: Font
        let input: Font
        let titleMeasure: NSFont
        let detailMeasure: NSFont

        init(_ sizes: Theme.TypeSizes) {
            self.sizes = sizes
            title = Self.font(\.title, of: sizes)
            body = Self.font(\.body, of: sizes)
            detail = Self.font(\.detail, of: sizes)
            input = Self.font(\.input, of: sizes)
            titleMeasure = NSFont.systemFont(ofSize: sizes.title, weight: .medium)
            detailMeasure = NSFont.systemFont(ofSize: sizes.detail)
        }

        static func font(_ part: KeyPath<Theme.TypeSizes, Double>, of sizes: Theme.TypeSizes) -> Font {
            part == \.title ? Font.system(size: sizes.title, weight: .medium) : Font.system(size: sizes[keyPath: part])
        }
    }

    nonisolated(unsafe) private static var faces = Faces(Theme.TypeSizes())
    nonisolated(unsafe) static let builtIn = Faces(Theme.TypeSizes())

    static func take(_ sizes: Theme.TypeSizes) {
        if sizes != faces.sizes { faces = Faces(sizes) }
    }

    static func face(_ part: KeyPath<Theme.TypeSizes, Double>) -> Font {
        Faces.font(part, of: faces.sizes)
    }

    static var titleSize: CGFloat { faces.sizes.title }
    static var detailSize: CGFloat { faces.sizes.detail }
    static var title: Font { faces.title }
    static var body: Font { faces.body }
    static var detail: Font { faces.detail }
    @MainActor static var titleMeasure: NSFont { faces.titleMeasure }
    @MainActor static var detailMeasure: NSFont { faces.detailMeasure }
    static var input: Font { faces.input }
    static let keycapSymbol = Font.system(size: 22, weight: .medium)
    static let keycapKey = Font.system(size: 17, weight: .medium)
    static let keycapName = Font.system(size: 9, weight: .medium)
    static let action = Font.system(size: 11, weight: .medium)
    static let metric = Font.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit()
    static let ringValue = Font.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()
    static let value = Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
    static let controlValue = Font.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()
    static let menuBar = Font.system(size: 13, weight: .medium).monospacedDigit()
    static let small = Font.system(size: 10, weight: .medium)
    static let strong = Font.system(size: 13, weight: .semibold)
    static let rowIcon = Font.system(size: 14)
    static let glyph = Font.system(size: 17, weight: .semibold)
    static let mark = Font.system(size: 9, weight: .semibold)
    static let code = Font.system(size: 12, design: .monospaced)
    static let chevron = Font.system(size: 12, weight: .semibold)
    static let cornerMark = Font.system(size: 10, weight: .bold)
    static let cornerFault = Font.system(size: 10, weight: .semibold)
    static let number = Font.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit()
    static let lineGap: CGFloat = 1
    static var titleLine: CGFloat { faces.sizes.title + 3 }
    static var detailLine: CGFloat { faces.sizes.detail + 3 }
    static var inputLine: CGFloat { faces.sizes.input + 4 }
}
