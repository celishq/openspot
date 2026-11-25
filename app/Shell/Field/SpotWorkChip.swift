import OpenspotCore
import SwiftUI

struct SpotWorkChip: View {
    let model: SpotsModel
    let isShown: Bool


    var body: some View {
        ZStack {
            let all = model.unseenWork
            if let work = all.first {
                SpotShine {
                    HStack(spacing: SpotTokens.workChipGap) {
                        Image(systemName: "sparkles")
                        if all.count > 1 { Text("\(all.count)") }
                    }
                    .font(SpotType.action)
                }
                .foregroundStyle(SpotTheme.ink)
                .padding(.horizontal, all.count > 1 ? SpotTokens.padding / 2 : 0)
                .frame(minWidth: SpotTokens.workChipSide, minHeight: SpotTokens.workChipSide)
                .background(SpotTheme.ink.opacity(SpotTheme.control), in: Capsule())
                .contentShape(Capsule())
                .onTapGesture { model.open(work.id) }
                .help(all.map { $0.call.title ?? "Working…" }.joined(separator: "\n"))
                .accessibilityLabel(work.call.title ?? "Working…")
                .accessibilityAddTraits(.isButton)
                .opacity(isShown ? 1 : MotionTokens.hiddenOpacity)
                .allowsHitTesting(isShown)
            }
        }
        .padding(.trailing, SpotTokens.halo + SpotTokens.padding)
        .padding(.top, SpotTokens.halo + (SpotTokens.gridTop - SpotTokens.halo - SpotTokens.rowGap - SpotTokens.workChipSide) / 2)
        .frame(width: SpotTokens.panelWidth, height: SpotTokens.panelHeight, alignment: .topTrailing)
        .modifier(SpotShownFade(isShown: model.isShown))
    }
}
