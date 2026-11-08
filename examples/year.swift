import SwiftUI

/// The year over its twelve months as bars: the months that passed are full, and this month fills as it goes.
struct SpotView: View {
    let spot: SpotInput

    private var month: Int { Int(spot["month"] ?? "") ?? 0 }
    private var progress: Double { Double(spot["progress"] ?? "") ?? 0 }

    var body: some View {
        VStack(spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(spot["title"] ?? "").font(.headline)
                Spacer(minLength: 4)
                Text("\(spot["left"] ?? "–") days left").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(1...12, id: \.self) { index in
                    let fill = index < month ? 1 : index == month ? progress : 0
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.primary.opacity(0.12))
                        .overlay(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(index == month ? Color.orange : .primary.opacity(0.7))
                                .frame(height: 12 * fill)
                        }
                        .frame(height: 12)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }
}
