import SwiftUI

/// The sizes and weights of all text, on the Mac's own scale.
enum SpotType {
    static let title = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 13)
    static let detail = Font.system(size: 11)
    static let input = Font.system(size: 14)
    static let action = Font.system(size: 11, weight: .medium)
    static let metric = Font.system(size: 30, weight: .semibold, design: .rounded).monospacedDigit()
    static let ringValue = Font.system(size: 20, weight: .semibold, design: .rounded).monospacedDigit()
    static let value = Font.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit()
    static let controlValue = Font.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()
    static let tray = Font.system(size: 13, weight: .medium).monospacedDigit()
    static let small = Font.system(size: 10, weight: .medium)
    static let keycap = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let lineGap: CGFloat = 1
}
