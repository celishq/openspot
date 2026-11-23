import OpenspotCore
import SwiftUI

struct WorkCardBar: View {
    let fill: WorkFill
    let width: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: MotionTokens.workTick)) { context in
            let value = fill.value(at: context.date)
            Capsule()
                .fill(SpotTheme.ink.opacity(SpotTheme.track))
                .overlay {
                    Capsule()
                        .fill(SpotTheme.ink)
                        .offset(x: -(1 - value) * width)
                        .animation(SpotMotion.creep, value: value)
                }
                .clipShape(Capsule())
                .frame(width: width, height: SpotTokens.workBarHeight)
        }
    }
}
