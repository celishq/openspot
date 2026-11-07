import SwiftUI

/// One line of text whose matched letters show in full ink at semibold. When some letters match, the rest drops to the
/// given strength, so that the match stands out.
struct SpotMarkedText: View {
    let text: String
    let marks: [Range<Int>]
    let font: Font
    let ink: Color
    var strength: Double = 1
    var markedStrength: Double = 1

    var body: some View {
        Text(marked).lineLimit(1)
    }

    private var marked: AttributedString {
        var result = AttributedString()
        var offset = 0
        for range in marks where range.lowerBound >= offset && range.upperBound <= text.count {
            result += part(offset..<range.lowerBound, isMarked: false)
            result += part(range, isMarked: true)
            offset = range.upperBound
        }
        result += part(offset..<text.count, isMarked: false)
        return result
    }

    private func part(_ range: Range<Int>, isMarked: Bool) -> AttributedString {
        let start = text.index(text.startIndex, offsetBy: range.lowerBound)
        let end = text.index(text.startIndex, offsetBy: range.upperBound)
        var part = AttributedString(String(text[start..<end]))
        part.font = isMarked ? font.weight(.semibold) : font
        part.foregroundColor = ink.opacity(isMarked ? markedStrength : marks.isEmpty ? strength : strength * SpotTheme.unmarked)
        return part
    }
}
