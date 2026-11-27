import OpenspotCore
import SwiftUI

struct SettingsPlacePicture: View {
    let place: SpotPlace
    let spot: Spot
    let isOn: Bool

    var body: some View {
        ZStack {
            SpotTheme.highlight.opacity(SpotTheme.fill)
            switch place {
            case .searchField: field
            case .menuBar: menuBar
            case .window: window
            }
        }
        .frame(width: SpotTokens.settingsPlaceWidth, height: SpotTokens.settingsPlaceHeight)
    }

    private var chip: AttachmentChip {
        AttachmentChip(source: spot.id, app: nil, look: spot.attachmentLook ?? .symbol(AttachmentChip.loadingSymbol), state: .unread)
    }

    private var shown: Double {
        isOn ? 1 : MotionTokens.hiddenOpacity
    }

    private var field: some View {
        HStack(spacing: 0) {
            SpotFieldPrompt.glyph
            Spacer(minLength: 0)
            SpotAttachmentCard(chip: chip, showsBadge: false, isQuiet: false)
                .opacity(shown)
        }
        .padding(.horizontal, SpotTokens.attachmentReach)
        .frame(width: SpotTokens.settingsPlaceFieldWidth, height: SpotTokens.layout.fieldHeight)
        .background { SpotRoundShape(SurfaceEdge(card: .strip)).fill(SpotTheme.attachmentFace) }
        .scaleEffect(SpotTokens.settingsPlaceScale)
    }

    private var menuBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: SpotTokens.settingsPlaceSymbol) {
                Spacer(minLength: 0)
                symbol(spot.symbol)
                    .opacity(shown)
                ForEach(Self.menuBarItems, id: \.self) { symbol($0).foregroundStyle(.secondary) }
            }
            .padding(.horizontal, SpotTokens.settingsPlaceSymbol)
            .frame(height: SpotTokens.settingsPlaceBar)
            .background(SpotTheme.attachmentFace)
            Spacer(minLength: 0)
        }
    }

    private var window: some View {
        VStack(spacing: 0) {
            SpotTheme.highlight.opacity(SpotTheme.fill)
                .frame(height: SpotTokens.settingsPlaceBar)
            SettingsSpotIcon(spot: spot, side: SpotTokens.settingsPlaceWindowIcon)
                .opacity(shown)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: SpotTokens.settingsPlaceWindowWidth, height: SpotTokens.settingsPlaceWindowHeight)
        .background(SpotTheme.attachmentFace)
        .clipShape(SpotRoundShape(radius: SpotTokens.settingsPlaceWindowRadius))
    }

    private static let menuBarItems = ["wifi", "battery.75percent"]

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .resizable()
            .scaledToFit()
            .frame(width: SpotTokens.settingsPlaceSymbol, height: SpotTokens.settingsPlaceSymbol)
    }
}
