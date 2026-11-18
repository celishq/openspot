import CoreGraphics
import CoreText
import Foundation

public enum SheetHeading {
    public static let titleSize: CGFloat = 24
    public static let detailSize: CGFloat = 15
    public static let gap: CGFloat = 6
    public static let pictureHeight: CGFloat = 38
    public static let pictureGap: CGFloat = 12
    public static let noteHeight: CGFloat = 41
    public static let noteGap: CGFloat = 4
    public static let noteBottom: CGFloat = 4
    public static let side: CGFloat = 6

    public static func height(of part: SpotPart, width: CGFloat) -> CGFloat {
        let blocks = [
            part.title.map { (height: lines($0, bold: true, size: titleSize, width: width), isPicture: false) },
            part.image.map { _ in (height: pictureHeight, isPicture: true) },
            part.detail.map { (height: lines($0, bold: false, size: detailSize, width: width), isPicture: false) },
        ].compactMap { $0 }
        let gaps = zip(blocks, blocks.dropFirst()).map { $0.isPicture || $1.isPicture ? pictureGap : gap }
        let words = blocks.map(\.height).reduce(0, +) + gaps.reduce(0, +)
        guard part.note != nil else { return words }
        return words + (blocks.isEmpty ? 0 : noteGap) + noteHeight
    }

    private static func lines(_ words: String, bold: Bool, size: CGFloat, width: CGFloat) -> CGFloat {
        let font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, size, nil)
        let text = NSAttributedString(string: words, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font as Any])
        let setter = CTFramesetterCreateWithAttributedString(text)
        let room = CGSize(width: width, height: .greatestFiniteMagnitude)
        return CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(), nil, room, nil).height.rounded(.up)
    }
}
