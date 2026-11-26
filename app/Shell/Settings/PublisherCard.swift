import OpenspotCore
import SwiftUI

struct PublisherCard: View {
    let account: AccountStatus?
    let act: () -> Void
    @Environment(\.controlActiveState) private var activeState
    @Environment(\.spotMoves) private var moves
    @State private var pointer: CGPoint?
    @State private var tilt = CardTilt()
    @State private var isOnPill = false

    var body: some View {
        let look = KeyLook(key: account?.npub ?? "openspot")
        let size = Self.size
        let place = CGSize(width: size.width + 2 * SpotTokens.publisherTiltReach.width, height: size.height + 2 * SpotTokens.publisherTiltReach.height)
        TimelineView(.animation(paused: !moves || activeState != .key && pointer == nil)) { context in
            card(look, size: size, tilt: moves ? tilt.next(toward: pointer, at: context.date.timeIntervalSinceReferenceDate) : .zero)
        }
        .frame(width: place.width, height: place.height)
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let at):
                let x = (at.x - place.width / 2) / (size.width / 2), y = (at.y - place.height / 2) / (size.height / 2)
                pointer = CGPoint(x: min(max(x, -1), 1), y: min(max(y, -1), 1))
            case .ended: pointer = nil
            }
        }
    }

    static var size: CGSize {
        CGSize(width: SpotTokens.publisherWidth, height: SpotTokens.publisherWidth / SpotTokens.publisherRatio)
    }

    private func card(_ look: KeyLook, size: CGSize, tilt: CGPoint) -> some View {
        let shape = SpotRoundShape(radius: SpotTokens.publisherRadius)
        let pill = pillSize
        return ZStack {
            Rectangle().fill(SpotTheme.foilBase).colorEffect(look.shader(size: size, tilt: tilt))
            Rectangle().fill(SpotTheme.foilBase).colorEffect(look.shader(size: size, tilt: tilt))
                .blur(radius: SpotTokens.publisherPillBlur)
                .mask(alignment: .bottomTrailing) { Capsule().frame(width: pill.width, height: pill.height).padding(SpotTokens.publisherInset) }
            face(look, tilt: tilt)
            glassPill(look, size: pill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(SpotTokens.publisherInset)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(SpotTheme.publisherRim, lineWidth: SpotTokens.publisherRim))
        .rotation3DEffect(.degrees(tilt.x * MotionTokens.cardTurn), axis: (x: 0, y: 1, z: 0), perspective: MotionTokens.cardPerspective)
        .rotation3DEffect(.degrees(-tilt.y * MotionTokens.cardLean), axis: (x: 1, y: 0, z: 0), perspective: MotionTokens.cardPerspective)
    }

    private func face(_ look: KeyLook, tilt: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("OPENSPOT PUBLISHER").font(SpotType.publisherTitle).tracking(SpotType.publisherTracking)
                Spacer()
                CardEmblem(dots: look.emblem).fill(look.engrave).frame(width: SpotTokens.emblemSide, height: SpotTokens.emblemSide)
            }
            Spacer(minLength: 0)
            if let account {
                if let handle = account.handle {
                    Text("@\(handle)").font(SpotType.publisherHandle).lineLimit(1).minimumScaleFactor(SpotType.leastValueScale)
                }
            } else {
                Text("@yourname").font(SpotType.publisherHandle).opacity(SpotTheme.publisherBlank)
            }
            HStack(alignment: .bottom) {
                if let since = account?.since { Text("Since \(since)").font(SpotType.publisherSince) }
                Spacer(minLength: 0)
            }
            .frame(height: pillSize.height, alignment: .bottom)
            .padding(.top, SpotTokens.publisherLineGap)
        }
        .padding(SpotTokens.publisherInset)
        .foregroundStyle(look.engrave)
        .shadow(color: look.catchLight, radius: 0, x: -tilt.x * SpotTokens.publisherCatchShift, y: 1 - tilt.y * SpotTokens.publisherCatchShift)
    }

    private var pillWords: String {
        account?.shortNpub ?? "Create a New Key…"
    }

    private var pillSize: CGSize {
        CGSize(width: Double(pillWords.count) * SpotTokens.publisherPillCharWidth + SpotTokens.publisherPillRoom, height: SpotTokens.publisherPillHeight)
    }

    private func glassPill(_ look: KeyLook, size: CGSize) -> some View {
        HStack(spacing: SpotTokens.publisherPillGap) {
            Text(pillWords).font(SpotType.publisherKey)
            Image(systemName: account == nil ? "plus" : "doc.on.doc").font(SpotType.publisherCopy)
        }
        .foregroundStyle(account == nil ? look.inverse : look.engrave)
        .frame(width: size.width, height: size.height)
        .background(Capsule().fill(look.engrave.opacity(account == nil ? 1 : isOnPill ? SpotTheme.publisherPillHover : SpotTheme.publisherPill)))
        .overlay(Capsule().strokeBorder(look.engrave.opacity(SpotTheme.publisherPillRing), lineWidth: SpotTokens.publisherRim))
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [SpotTheme.publisherPillShine, .clear], startPoint: .top, endPoint: .center), lineWidth: SpotTokens.publisherRim))
        .contentShape(Capsule())
        .onHover { isOnPill = $0 }
        .onTapGesture(perform: act)
        .accessibilityAddTraits(.isButton)
        .help(account == nil ? "Create a key that signs the spots you publish" : "Copy your whole key")
    }
}
