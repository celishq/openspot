import SwiftUI

/// The Agents card at each size: rings of the agents last active when it is small, a list of the sessions when it is
/// square, the limits when it is a strip, and the limits over as many sessions as fit when it is large.
struct SpotView: View {
    let spot: SpotInput

    private var rowHeight: CGFloat { shape == .large ? 22 : 26 }

    private var limits: [[String]] { (1...2).compactMap { spot["limit\($0)"] }.map { $0.components(separatedBy: "|") } }
    private var tasks: [[String]] { (1...6).compactMap { spot["task\($0)"] }.map { $0.components(separatedBy: "|") } }

    private var shape: SpotCard {
        if let card = spot.card { return card }
        if spot.size.width < 100 { return .small }
        if spot.size.height < 100 { return spot.size.width < 200 ? .wide : .strip }
        return spot.size.width < 200 ? .square : .large
    }

    var body: some View {
        Group {
            switch shape {
            case .small: rings(limits.prefix(1))
            case .wide: rings(limits.prefix(2))
            case .square: list
            case .strip: meters
            case .large:
                VStack(alignment: .leading, spacing: spot.inset * 0.5) {
                    meters
                    list
                }
            }
        }
        .padding(shape == .small || shape == .wide ? 0 : shape == .square ? spot.inset * 0.7 : spot.inset)
        .frame(width: spot.size.width, height: spot.size.height, alignment: shape == .small || shape == .wide ? .center : .topLeading)
    }

    private func rings(_ shown: ArraySlice<[String]>) -> some View {
        let cell = spot.theme.space.cell
        return HStack(spacing: spot.columnGap) {
            ForEach(Array(shown), id: \.self) { limit in
                ZStack {
                    ring(Double(limit[1]) ?? 0, side: cell - spot.inset * 2, line: (cell - spot.inset * 2) * 0.11, tint: tint(limit))
                    logo(limit[0], side: (cell - spot.inset * 2) * 0.36, tint: tint(limit))
                }
                .frame(width: cell, height: cell)
            }
        }
        .frame(width: spot.size.width, height: spot.size.height)
    }

    private func ring(_ used: Double, side: CGFloat, line: CGFloat, tint: Color) -> some View {
        ZStack {
            Circle().stroke(spot.ink.opacity(spot.theme.color.track), lineWidth: line)
            Circle()
                .trim(from: 0, to: used)
                .stroke(tint, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: side - line, height: side - line)
    }

    private var meters: some View {
        HStack(spacing: spot.inset) {
            ForEach(limits, id: \.self) { meter($0) }
        }
        .frame(maxHeight: shape == .strip ? .infinity : nil)
    }

    @ViewBuilder
    private func meter(_ limit: [String]) -> some View {
        let used = Double(limit[1]) ?? 0
        if shape == .large || shape == .strip {
            HStack(spacing: 8) {
                logo(limit[0], side: 14, tint: tint(limit))
                bar(used, tint: tint(limit))
                Text("\(Int(used * 100))%").font(spot.theme.font.body.bold()).monospacedDigit().foregroundStyle(spot.ink)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    logo(limit[0], side: 15, tint: tint(limit))
                    Spacer()
                    Text("\(Int(used * 100))%").font(spot.theme.font.body.bold()).monospacedDigit().foregroundStyle(spot.ink)
                }
                bar(used, tint: tint(limit))
            }
        }
    }

    private func bar(_ used: Double, tint: Color) -> some View {
        GeometryReader { box in
            ZStack(alignment: .leading) {
                Capsule().fill(spot.ink.opacity(spot.theme.color.track))
                Capsule().fill(tint).frame(width: box.size.width * used)
            }
        }
        .frame(height: 5)
    }

    private var list: some View {
        GeometryReader { room in
            let tall = shape == .square ? rowHeight * 1.5 : rowHeight
            let count = max(0, min(tasks.count, Int(room.size.height / tall + 0.2)))
            VStack(spacing: 0) {
                if tasks.isEmpty {
                    Text("No agent is running").font(spot.theme.font.detail).foregroundStyle(spot.ink.opacity(spot.secondary))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                ForEach(Array(tasks.prefix(count).enumerated()), id: \.offset) { _, task in
                    if shape == .square { self.tall(task) } else { row(task) }
                }
            }
            .padding(.horizontal, -8)
        }
    }

    private func row(_ task: [String]) -> some View {
        let waits = task[0] == "waiting"
        let tint = waits ? spot.theme.color.warn : spot.theme.color.good
        return HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .shadow(color: tint.opacity(0.8), radius: 4)
            Text(task[1])
                .font(spot.theme.font.body.weight(waits ? .semibold : .regular))
                .foregroundStyle(spot.ink)
                .lineLimit(1)
            Spacer(minLength: 4)
            logo(task[2], side: 14)
        }
        .padding(.horizontal, 8)
        .frame(height: rowHeight - 2)
        .background(waits ? tint.opacity(0.16) : .clear, in: Capsule())
        .frame(height: rowHeight)
    }

    private func tall(_ task: [String]) -> some View {
        let waits = task[0] == "waiting"
        let tint = waits ? spot.theme.color.warn : spot.theme.color.good
        return HStack(spacing: 8) {
            logo(task[2], side: 14)
            VStack(alignment: .leading, spacing: 1) {
                Text(task[1])
                    .font(spot.theme.font.body.weight(waits ? .semibold : .regular))
                    .foregroundStyle(spot.ink)
                Text(waits ? "Needs you" : task[3])
                    .font(spot.theme.font.detail.weight(waits ? .semibold : .regular))
                    .foregroundStyle(waits ? tint : spot.ink.opacity(spot.secondary))
            }
            .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(height: rowHeight * 1.5 - 2)
        .background(waits ? tint.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .frame(height: rowHeight * 1.5)
    }

    /// The colour of an agent's marks: the colour of a session that waits for you when one of its sessions waits.
    private func tint(_ limit: [String]) -> Color {
        limit.count > 2 && limit[2] == "waiting" ? spot.theme.color.warn : spot.ink
    }

    private func logo(_ file: String, side: CGFloat, tint: Color? = nil) -> some View {
        Image(nsImage: NSImage(data: Data(base64Encoded: Logo.png[file] ?? "") ?? Data()) ?? NSImage())
            .renderingMode(.template)
            .resizable()
            .foregroundStyle(tint ?? spot.ink)
            .frame(width: side, height: side)
    }
}

enum Logo {
    static let png = [
        "claude": "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",
        "openai": "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",
    ]
}
