import SwiftUI
import OpenspotCore

struct ShelfView: View {
    let model: ShelfModel
    let close: () -> Void
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Search", text: Binding(get: { model.query }, set: { model.query = $0 }))
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(12)
                .focused($searchFocused)
                .onSubmit {
                    if model.runSelected() { close() }
                }
                .onKeyPress(.downArrow) {
                    model.moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    model.moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.escape) {
                    close()
                    return .handled
                }
            Divider()
            ScrollViewReader { proxy in
                List {
                    ForEach(Array(model.visibleRows.enumerated()), id: \.offset) { index, row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.title)
                            if let subtitle = row.subtitle {
                                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .background(index == model.selected ? Color.accentColor.opacity(0.2) : Color.clear)
                        .id(index)
                        .onTapGesture {
                            model.run(row)
                            close()
                        }
                    }
                }
                .onChange(of: model.selected) { _, value in
                    proxy.scrollTo(value)
                }
            }
            if !model.problems.isEmpty {
                Text(model.problems.joined(separator: "\n"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
        .frame(width: 480, height: 320)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear { searchFocused = true }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            searchFocused = true
        }
    }
}
