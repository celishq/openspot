import OpenspotCore
import SwiftUI

/// The listing of a spot in the store, in a sheet under the shelf of its card: its name and description, its readme, the
/// rows of its preview, and a button that copies a prompt for the person's agent. It grows out of the bottom of its card.
struct SpotListingSheet: View {
    let item: SpotDock.Item
    let listing: SpotListing
    let model: SpotsModel

    var body: some View {
        VStack(alignment: .leading, spacing: SpotTokens.padding) {
            HStack(spacing: SpotTokens.padding) {
                SpotItemIcon(icon: item.command.icon, glyph: item.command.glyph, symbol: item.command.symbol, size: SpotTokens.glyphSize)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.command.name)
                        .font(SpotType.title)
                        .foregroundStyle(SpotTheme.ink)
                    if let description = listing.description {
                        Text(description)
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText())
                    }
                }
                Spacer(minLength: 0)
                ListingButton(title: item.isOwn ? "Copy prompt to change" : "Copy prompt to review") { model.copyListingPrompt(item.id) }
            }
            HStack(alignment: .top, spacing: SpotTokens.sideGap) {
                ScrollView(.vertical, showsIndicators: false) {
                    Text(readme)
                        .font(SpotType.body)
                        .foregroundStyle(SpotTheme.ink)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                if !listing.preview.isEmpty {
                    VStack(alignment: .leading, spacing: SpotTokens.listRowGap) {
                        Text("Preview")
                            .font(SpotType.detail)
                            .modifier(SpotSecondaryText())
                        ForEach(Array(listing.preview.prefix(4).enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(row.title)
                                    .font(SpotType.body)
                                    .foregroundStyle(SpotTheme.ink)
                                if let detail = row.subtitle {
                                    Text(detail)
                                        .font(SpotType.detail)
                                        .modifier(SpotSecondaryText())
                                }
                            }
                            .lineLimit(1)
                        }
                    }
                    .frame(width: SpotTokens.gridWidth, alignment: .topLeading)
                }
            }
        }
        .padding(SpotTokens.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SpotTheme.ink.opacity(SpotTheme.fill), in: RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous))
    }

    /// The readme with its inline Markdown, or words that say it has none.
    private var readme: AttributedString {
        guard let text = listing.readme else { return AttributedString("This spot has no readme yet.") }
        return (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

/// A button of the listing: its title on a keycap capsule.
private struct ListingButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SpotType.action)
                .foregroundStyle(SpotTheme.ink)
                .padding(.horizontal, SpotTokens.controlPadding * 2)
                .frame(height: SpotTokens.menuRowHeight - SpotTokens.controlPadding)
                .background(SpotTheme.keycap, in: Capsule())
                .overlay(Capsule().strokeBorder(SpotTheme.ink.opacity(SpotTheme.track)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// A rounded rectangle at a place that moves, which clips a sheet while it grows out of its card.
struct SpotSheetClip: Shape {
    var rect: CGRect

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(rect.minX, rect.minY), AnimatablePair(rect.width, rect.height)) }
        set { rect = CGRect(x: newValue.first.first, y: newValue.first.second, width: newValue.second.first, height: newValue.second.second) }
    }

    func path(in bounds: CGRect) -> Path {
        RoundedRectangle(cornerRadius: SpotTokens.radius, style: .continuous).path(in: rect)
    }
}
