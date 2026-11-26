import OpenspotCore
import SwiftUI

struct KeyFill: TextRenderer {
    struct Key: TextAttribute {}

    let fill: Color

    static func text(_ message: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        let parsed = (try? AttributedString(markdown: message, options: options)) ?? AttributedString(message)
        return parsed.runs.reduce(Text(verbatim: "")) { text, run in
            let words = String(parsed[run.range].characters)
            guard run.inlinePresentationIntent?.contains(.code) == true else { return Text("\(text)\(Text(verbatim: words))") }
            let key = Text(verbatim: "\u{2009}\(words)\u{2009}").customAttribute(Key())
            return Text("\(text)\(Text(verbatim: "\u{2009}"))\(key)\(Text(verbatim: "\u{2009}"))")
        }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                if run[Key.self] != nil {
                    let rect = run.typographicBounds.rect.insetBy(dx: SpotTokens.toastKeySpace - SpotTokens.hintKeyPadding, dy: 0)
                    context.fill(Capsule().path(in: rect), with: .color(fill))
                }
                context.draw(run)
            }
        }
    }
}
