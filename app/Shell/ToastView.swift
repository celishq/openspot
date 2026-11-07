import SwiftUI

/// A short message from Openspot on the same surface as a spot.
struct ToastView: View {
    let toast: Toast

    var body: some View {
        HStack(spacing: 8) {
            if let symbol = toast.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SpotTheme.ink)
            }
            Text(Self.styled(toast.message))
                .font(SpotType.body)
                .foregroundStyle(SpotTheme.ink)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, ToastPanel.margin)
        .padding(.vertical, 10)
        .frame(minWidth: ToastPanel.minWidth - 2 * ToastPanel.margin, alignment: .leading)
        .modifier(SpotGlass(radius: SpotTokens.rowHeight / 3))
        .contentShape(Rectangle())
        .onTapGesture { toast.open?() }
        .padding(ToastPanel.margin)
        .environment(\.spotIsShown, toast.isShown)
    }

    /// The message with each span in backticks drawn as a key, on the fill of a key label.
    static func styled(_ message: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        var text = (try? AttributedString(markdown: message, options: options)) ?? AttributedString(message)
        let keys = text.runs.filter { $0.inlinePresentationIntent?.contains(.code) == true }.map(\.range)
        for range in keys.reversed() {
            var key = AttributedString("\u{2009}\(String(text[range].characters))\u{2009}")
            key.swiftUI.backgroundColor = SpotTheme.ink.opacity(SpotTheme.selectedFill)
            text.replaceSubrange(range, with: key)
        }
        return text
    }
}
