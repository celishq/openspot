import SwiftUI
import OpenspotCore

struct ShelfView: View {
    let model: ShelfModel
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List(model.rows, id: \.run) { row in
                Button {
                    model.run(row)
                    close()
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                        if let subtitle = row.subtitle {
                            Text(subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if !model.problems.isEmpty {
                Text(model.problems.joined(separator: "\n"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .frame(width: 480, height: 320)
    }
}
