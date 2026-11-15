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
        AnyView(PublisherCard(values: values, place: card["size"] as? CGSize ?? CGSize(width: 263, height: 178), send: send))
    }

    private func value(_ key: String) -> String? {
        values[key]?.last
    }

    static func fit(in place: CGSize) -> CGSize {
        let ratio = 263.0 / 166.0
        let width = min(place.width, place.height * ratio)
        return CGSize(width: width, height: width / ratio)
    }

    private func card(_ look: KeyLook, size: CGSize, tilt: CGPoint) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let pill = pillSize
        return ZStack {
            Rectangle().fill(.white).colorEffect(look.shader(size: size, tilt: tilt))
            Rectangle().fill(.white).colorEffect(look.shader(size: size, tilt: tilt))
                .blur(radius: 6)
                .mask(alignment: .bottomTrailing) { Capsule().frame(width: pill.width, height: pill.height).padding(16) }
            face(look, tilt: tilt)
            glassPill(look, size: pill)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(16)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.3), lineWidth: 1))
        .rotation3DEffect(.degrees(tilt.x * MotionTokens.cardTurn), axis: (x: 0, y: 1, z: 0), perspective: MotionTokens.cardPerspective)
        .rotation3DEffect(.degrees(-tilt.y * MotionTokens.cardLean), axis: (x: 1, y: 0, z: 0), perspective: MotionTokens.cardPerspective)
        .shadow(color: .black.opacity(0.5), radius: 12, x: -tilt.x * 8, y: 8 - tilt.y * 6)
    }

    private func face(_ look: KeyLook, tilt: CGPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            top(look)
            Spacer(minLength: 0)
            if let name = value("name") {
                Text(name).font(.system(size: 24, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
            }
            bottom.padding(.top, 8)
        }
        .padding(16)
        .foregroundStyle(look.engrave)
        .shadow(color: look.catchLight, radius: 0, x: -tilt.x * 0.8, y: 1 - tilt.y * 0.8)
    }

    private func top(_ look: KeyLook) -> some View {
        HStack(alignment: .top) {
            Text("OPENSPOT PUBLISHER").font(.system(size: 9.5, weight: .bold)).tracking(1.9)
            Spacer()
            CardEmblem(dots: look.emblem).fill(look.engrave).frame(width: 26, height: 26)
        }
    }

    private var bottom: some View {
        HStack(alignment: .bottom) {
            if let since = value("since") { Text("Since \(since)").font(.system(size: 10.5, weight: .medium)) }
            Spacer(minLength: 0)
        }
        .frame(height: pillSize.height, alignment: .bottom)
    }

    private var pillSize: CGSize {
        CGSize(width: Double((value("short") ?? "").count) * 6.3 + 33, height: 22)
    }

    private func glassPill(_ look: KeyLook, size: CGSize) -> some View {
        HStack(spacing: 5) {
            Text(value("short") ?? "").font(.system(size: 10.5, weight: .medium, design: .monospaced))
            Image(systemName: "doc.on.doc").font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(look.engrave)
        .frame(width: size.width, height: size.height)
        .background(Capsule().fill(look.engrave.opacity(isOnPill ? 0.18 : 0.1)))
        .overlay(Capsule().strokeBorder(look.engrave.opacity(0.22), lineWidth: 1))
        .overlay(Capsule().strokeBorder(LinearGradient(colors: [.white.opacity(0.45), .clear], startPoint: .top, endPoint: .center), lineWidth: 1))
        .contentShape(Capsule())
        .onHover { isOnPill = $0 }
        .onTapGesture { send("copy") }
        .help("Copy your whole key")
    }
}
