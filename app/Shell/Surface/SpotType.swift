import AppKit
import SwiftUI

enum SpotType {
    static let titleSize: CGFloat = 13
    static let detailSize: CGFloat = 11
    static let title = Font.system(size: titleSize, weight: .medium)
    static let body = Font.system(size: 13)
    static let detail = Font.system(size: detailSize)
    @MainActor static let titleMeasure = NSFont.systemFont(ofSize: titleSize, weight: .medium)
    @MainActor static let detailMeasure = NSFont.systemFont(ofSize: detailSize)
    static let input = Font.system(size: 14)
    static let action = Font.system(size: 11, weight: .medium)
    static let metric = Font.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit()
    static let ringValue = Font.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()
    static let value = Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
    static let controlValue = Font.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()
    static let menuBar = Font.system(size: 13, weight: .medium).monospacedDigit()
    static let small = Font.system(size: 10, weight: .medium)
    static let keycap = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let strong = Font.system(size: 13, weight: .semibold)
    static let glyph = Font.system(size: 17, weight: .semibold)
    static let mark = Font.system(size: 9, weight: .semibold)
    static let code = Font.system(size: 12, design: .monospaced)
    static let chevron = Font.system(size: 12, weight: .semibold)
    static let cornerMark = Font.system(size: 10, weight: .bold)
    static let cornerFault = Font.system(size: 10, weight: .semibold)
    static let number = Font.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit()
    static let lineGap: CGFloat = 1
    static let titleLine: CGFloat = 16
    static let detailLine: CGFloat = 14
    static let inputLine: CGFloat = 18
}
