import OpenspotCore
import SwiftUI

struct PublisherCard: View {
    let values: [String: [String]]
    let place: CGSize
    let send: (String) -> Void
    @State private var pointer: CGPoint?
    @State private var tilt = CardTilt()
    @State private var isOnPill = false

    var body: some View {
        let look = KeyLook(key: value("npub") ?? "")
        let size = Self.fit(in: place)
        TimelineView(.animation) { context in
            card(look, size: size, tilt: tilt.next(toward: pointer, at: context.date.timeIntervalSinceReferenceDate))
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

    static func make(_ values: [String: [String]], _ card: [String: Any], _ send: @escaping (String) -> Void) -> AnyView {
        AnyView(PublisherCard(values: values, place: card["size"] as? CGSize ?? SpotTokens.publisherPlace, send: send))
    }

    private func value(_ key: String) -> String? {
        values[key]?.last
    }

    static func fit(in place: CGSize) -> CGSize {
        let ratio = SpotTokens.publisherRatio
        let reach = SpotTokens.publisherTiltReach
        let width = min(place.width - 2 * reach.width, (place.height - 2 * reach.height) * ratio)
        return CGSize(width: width, height: width / ratio)
    }

    private func card(_ look: KeyLook, size: CGSize, tilt: CGPoint) -> some View {
        let shape = RoundedRectangle(cornerRadius: SpotTokens.publisherRadius, style: .continuous)
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
        .overlay(shape.strokeBorder(SpotTheme.publisherRim, lineWidth: 1))
        .rotation3DEffect(.degrees(tilt.x * MotionTokens.cardTurn), axis: (x: 0, y: 1, z: 0), perspective: MotionTokens.cardPerspective)
        .rotation3DEffect(.degrees(-tilt.y * MotionTokens.cardLean), axis: (x: 1, y: 0, z: 0), perspective: MotionTokens.cardPerspective)
    }

    private func face(_ look: KeyLook, tilt: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            top(look)
            Spacer(minLength: 0)
            if let handle = value("handle") {
                Text("@\(handle)").font(SpotType.publisherHandle).lineLimit(1).minimumScaleFactor(SpotType.leastValueScale)
            }
            bottom.padding(.top, SpotTokens.publisherLineGap)
        }
        .padding(SpotTokens.publisherInset)
        .foregroundStyle(look.engrave)
        .shadow(color: look.catchLight, radius: 0, x: -tilt.x * SpotTokens.publisherCatchShift, y: 1 - tilt.y * SpotTokens.publisherCatchShift)
    }

    private func top(_ look: KeyLook) -> some View {
        HStack(alignment: .top) {
            Text("OPENSPOT PUBLISHER").font(SpotType.publisherTitle).tracking(SpotType.publisherTracking)
            Spacer()
            CardEmblem(dots: look.emblem).fill(look.engrave).frame(width: SpotTokens.emblemSide, height: SpotTokens.emblemSide)
        }
    }

    private var bottom: some View {
        HStack(alignment: .bottom) {
            if let since = value("since") { Text("Since \(since)").font(SpotType.publisherSince) }
            Spacer(minLength: 0)
        }
        .frame(height: pillSize.height, alignment: .bottom)
    }

    private var pillSize: CGSize {
        CGSize(width: Double((value("short") ?? "").count) * SpotTokens.publisherPillCharWidth + SpotTokens.publisherPillRoom, height: SpotTokens.publisherPillHeight)
    }

    private func glassPill(_ look: KeyLook, size: CGSize) -> some View {
        HStack(spacing: SpotTokens.publisherPillGap) {
            Text(value("short") ?? "").font(SpotType.publisherKey)
            Image(systemName: "doc.on.doc").font(SpotType.publisherCopy)
        }
        .foregroundStyle(look.engrave)
        .frame(width: size.width, height: size.height)
        .background(Capsule().fill(look.engrave.opacity(isOnPill ? SpotTheme.publisherPillHover : SpotTheme.publisherPill)))
        .overlay(Capsule().strokeBorder(look.engrave.opacity(SpotTheme.publisherPillRing), lineWidth: 1))
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [SpotTheme.publisherPillShine, .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
        .contentShape(Capsule())
        .onHover { isOnPill = $0 }
        .onTapGesture { send("copy") }
        .help("Copy your whole key")
    }
}
