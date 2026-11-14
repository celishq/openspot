import OpenspotCore
import SwiftUI

struct ToastView: View {
    let toast: Toast
    private static let markSide: CGFloat = 16

    var body: some View {
        HStack(spacing: 8) {
            if toast.kind == .work {
                SpotWorkMark(call: nil, side: Self.markSide)
            } else if let symbol = toast.kind.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SpotTheme.ink)
            }
            Self.styled(toast.message)
                .textRenderer(ToastKeyFill(fill: SpotTheme.ink.opacity(SpotTheme.track)))
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, ToastPanel.margin)
        .padding(.vertical, 10)
        .modifier(SpotGlass(radius: SpotTokens.rowHeight / 3))
        .contentShape(Rectangle())
        .onTapGesture { toast.open?() }
        .padding(ToastPanel.margin)
        .environment(\.spotIsShown, toast.isShown)
    }

    static func styled(_ message: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let parsed = (try? AttributedString(markdown: message, options: options)) ?? AttributedString(message)
        return parsed.runs.reduce(Text(verbatim: "")) { text, run in
            let words = String(parsed[run.range].characters)
            guard run.inlinePresentationIntent?.contains(.code) == true else { return Text("\(text)\(Text(verbatim: words))") }
            let key = Text(verbatim: "\u{2009}\(words)\u{2009}").customAttribute(ToastKeyFill.Key())
            return Text("\(text)\(Text(verbatim: "\u{2009}"))\(key)\(Text(verbatim: "\u{2009}"))")
        }
    }
}
