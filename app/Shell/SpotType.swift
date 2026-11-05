import SwiftUI

/// The sizes and weights of all text, on the Mac's own scale.
enum SpotType {
    static let title = Font.system(size: 13, weight: .medium)
    static let body = Font.system(size: 13)
    static let detail = Font.system(size: 11)
    static let input = Font.system(size: 14)
    static let action = Font.system(size: 11, weight: .medium)
    static let lineGap: CGFloat = 1
}
