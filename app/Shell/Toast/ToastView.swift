import OpenspotCore
import SwiftUI

struct ToastView: View {
    let toast: Toast
    let showsContent: Bool
    var width: CGFloat?
    var toasts: Toasts?

    var body: some View {
        content
            .opacity(showsContent ? 1 : MotionTokens.hiddenOpacity)
            .padding(.horizontal, SpotTokens.toastMargin)
            .padding(.vertical, SpotTokens.toastPaddingY)
            .frame(width: width)
            .modifier(SpotGlass(shape: SpotRoundShape(radius: SpotTokens.toastRadius)))
            .contentShape(Rectangle())
            .onTapGesture { toasts?.press(toast.id) }
            .environment(\.spotIsShown, toast.isShown)
    }

    @ViewBuilder
    private var content: some View {
        if let tree = toast.note.tree {
            NodeTree(tree: tree, pictureTimes: [:])
                .environment(\.spotSurfaceEdge, SurfaceEdge(radius: SpotTokens.toastRadius).inner(by: SpotTokens.toastPaddingY))
                .environment(\.spotNode, NodeContext(variants: [.toast]))
                .fixedSize()
                .allowsHitTesting(false)
        } else {
            HStack(spacing: SpotTokens.toastGlyphGap) {
                if toast.note.kind == .work {
                    SpotWorkMark(call: nil, side: SpotTokens.toastMarkSide)
                } else if let symbol = toast.note.kind.symbol {
                    Image(systemName: symbol)
                        .font(SpotType.strong)
                        .foregroundStyle(SpotTheme.ink)
                }
                Self.styled(toast.words)
                    .textRenderer(ToastKeyFill(fill: SpotTheme.highlight.opacity(SpotTheme.track)))
                    .font(SpotType.body)
                    .foregroundStyle(SpotTheme.ink)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
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
