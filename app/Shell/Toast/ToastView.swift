import OpenspotCore
import SwiftUI

struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: SpotTokens.toastGlyphGap) {
            if toast.kind == .work {
                SpotWorkMark(call: nil, side: SpotTokens.toastMarkSide)
            } else if let symbol = toast.kind.symbol {
                Image(systemName: symbol)
                    .font(SpotType.strong)
                    .foregroundStyle(SpotTheme.ink)
            }
            Self.styled(toast.message)
                .textRenderer(ToastKeyFill(fill: SpotTheme.highlight.opacity(SpotTheme.track)))
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, SpotTokens.toastMargin)
        .padding(.vertical, SpotTokens.toastPaddingY)
        .modifier(SpotGlass(shape: SpotRoundShape(radius: SpotTokens.toastRadius)))
        .contentShape(Rectangle())
        .onTapGesture { toast.open?() }
        .padding(SpotTokens.toastRoom)
        .environment(\.spotIsShown, toast.isShown)
        .id(SpotLoadedTheme.shared.layout)
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
