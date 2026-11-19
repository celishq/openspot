import SwiftUI

/// The store, laid out on 16 columns of the grid: a sidebar of 4 with the search, a row for All, Core and Yours, a row for each store
/// folder, the built-in Openspot first, and Add Store…, and 12 with each spot as its card at the size it takes on the grid, under the title of
/// its group. A plus on a card gets the spot, and a click opens a sheet with its readme, which it asks for then, and, when
/// it has sample data, its sheet to try. A store whose folder is gone shows Locate… and Remove. A footer holds a hint, the
/// sort and Done. Each spot is an item of the frame.
struct SpotView: View {
    let spot: SpotInput
    @State private var query = ""
    @State private var place = Place.origin(.all)
    @State private var folders: [Folder] = []
    @State private var order = Order.name
    @State private var opened: String?
    @State private var isTrying = false
    @State private var pending: String?
    @State private var readmes: [String: [Line]] = [:]
    @State private var hovered: String?
    @State private var tip: String?
    @Environment(\.openURL) private var openURL

    /// The row of the sidebar that is chosen: an origin, or a store by the path of its folder.
    private enum Place: Equatable {
        case origin(Origin)
        case store(String)
    }

    /// Where the spots that the sidebar keeps come from.
    private enum Origin: String, CaseIterable, Identifiable {
        case all = "All", core = "Core", mine = "Yours"

        var id: Self { self }

        /// The word of `openspot store list` for this origin, or nil for all.
        var word: String? {
            switch self {
            case .all: nil
            case .core: "core"
            case .mine: "mine"
            }
        }

        var symbol: String {
            switch self {
            case .all: "square.grid.2x2"
            case .core: "shippingbox"
            case .mine: "person.crop.circle"
            }
        }

        /// The tip of its row in the sidebar.
        var tip: String {
            switch self {
            case .all: "Show every spot"
            case .core: "Show the spots that come with Openspot"
            case .mine: "Show the spots you made"
            }
        }
    }

    /// A store folder: its path, its name, whether Openspot finds it, and whether it comes with Openspot, which has no Remove.
    private struct Folder: Identifiable, Equatable {
        let id: String
        let name: String
        let isFound: Bool
        let isBuiltIn: Bool

        init?(_ line: String) {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 4 else { return nil }
            (id, name, isFound, isBuiltIn) = (parts[0], parts[1], parts[2] == "found", parts[3] == "builtin")
        }
    }

    /// How the cards of each group are ordered.
    private enum Order: String, CaseIterable, Identifiable {
        case name = "Name", size = "Size"

        var id: Self { self }
    }

    /// The anchor of the control whose tip shows.
    private struct TipAnchor: PreferenceKey {
        static let defaultValue: Anchor<CGRect>? = nil

        static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
            value = value ?? nextValue()
        }
    }

    /// A line of a readme: a heading, a line of text with its inline styles, or a picture or a video with its caption.
    private enum Line {
        case heading(String)
        case text(AttributedString)
        case media(String, caption: String)

        init(_ line: String) {
            if line.hasPrefix("#") {
                self = .heading(line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces))
            } else if line.hasPrefix("!["), line.hasSuffix(")"), let middle = line.range(of: "]("), !line[middle.upperBound...].dropLast().contains(")") {
                self = .media(String(line[middle.upperBound..<line.index(before: line.endIndex)]), caption: String(line[line.index(line.startIndex, offsetBy: 2)..<middle.lowerBound]))
            } else {
                let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                self = .text((try? AttributedString(markdown: line, options: options)) ?? AttributedString(line))
            }
        }
    }

    /// One spot of the store, from its item: its id, its name, what its button does, its origin, its description, its size,
    /// whether it has sample data, and the folded words that a search compares, made once.
    private struct Item: Identifiable {
        let id: String
        let name: String
        let state: String
        let origin: String
        let store: String
        let detail: String
        let size: String
        let hasSample: Bool
        let words: String

        init?(_ row: SpotItem) {
            guard !row.id.isEmpty, let state = row["step"] else { return nil }
            (id, name, self.state, origin, detail, size) = (row.id, row["title"] ?? row.id, state, row["origin"] ?? "", row["detail"] ?? "", row["size"] ?? "")
            store = row["store"] ?? ""
            hasSample = row["sample"] == "true"
            words = [name, detail, Self.label(of: origin)].joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        }

        /// The word of the sidebar that names its origin.
        static func label(of origin: String) -> String {
            Origin.allCases.first { $0.word == origin }?.rawValue ?? origin
        }
    }

    private static let sidebarColumns: CGFloat = 4
    private static let line: CGFloat = 36
    private static let text: Font = .system(size: 13)
    private static let heading: Font = .system(size: 13, weight: .semibold)
    private static let caption: Font = .system(size: 11)

    /// The width of the sidebar: 4 of the 16 columns that fill the window.
    private var sidebarWidth: CGFloat {
        let columns = CGFloat(spot.columns)
        let column = (spot.size.width - 2 * spot.inset - (columns - 1) * spot.columnGap) / columns
        return max(Self.sidebarColumns * column + (Self.sidebarColumns - 1) * spot.columnGap, 180)
    }

    var body: some View {
        let all = spot.items.compactMap(Item.init)
        let items = kept(all)
        HStack(spacing: 0) {
            sidebar(all)
            VStack(spacing: 0) {
                ZStack {
                    if let folder = chosenFolder, !folder.isFound {
                        missing(folder)
                    } else {
                        gallery(items)
                        if items.isEmpty { empty }
                    }
                }
                footer
            }
        }
        .sheet(isPresented: Binding(get: { opened != nil }, set: { if !$0 { opened = nil } })) {
            if let opened, let item = all.first(where: { $0.id == opened }) { about(item) }
        }
        .task(id: spot["show"]) {
            if let id = spot["show"], let item = all.first(where: { $0.id == id }) { open(item) }
        }
        .overlayPreferenceValue(TipAnchor.self) { anchor in
            GeometryReader { proxy in
                if let anchor, let tip {
                    let rect = proxy[anchor]
                    let below = rect.maxY + 15 < proxy.size.height - 15
                    spot.tip(tip)
                        .position(x: min(max(rect.midX, 120), proxy.size.width - 120), y: below ? rect.maxY + 15 : rect.minY - 15)
                }
            }
            .allowsHitTesting(false)
        }
        .onChange(of: spot.answers, initial: true) {
            let asked = pending
            pending = nil
            let next = spot.all("folder").compactMap(Folder.init)
            if asked == "add" || asked?.hasPrefix("locate:") == true, let new = next.first(where: { folder in !folders.contains { $0.id == folder.id } }) {
                place = .store(new.id)
            }
            if next != folders { folders = next }
            if case .store(let id) = place, !next.contains(where: { $0.id == id }) { place = .origin(.all) }
            let lines = spot.all("readme").map { $0.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false) }
            for (id, parts) in Dictionary(grouping: lines, by: { String($0[0]) }) {
                readmes[id] = parts.filter { $0.count > 1 }.map { Line(String($0[1])) }
            }
        }
        .task(id: hovered) {
            tip = nil
            guard let hovered else { return }
            try? await Task.sleep(for: spot.tipDelay)
            if !Task.isCancelled { tip = hovered }
        }
    }

    /// The store that the sidebar has chosen, if a store is chosen.
    private var chosenFolder: Folder? {
        guard case .store(let id) = place else { return nil }
        return folders.first { $0.id == id }
    }

    /// Whether a spot belongs to the chosen row of the sidebar.
    private func isKept(_ item: Item) -> Bool {
        switch place {
        case .origin(let origin): origin.word == nil || item.origin == origin.word
        case .store(let id): item.store == id
        }
    }

    /// The spots that the search and the chosen row keep, in the chosen order.
    private func kept(_ all: [Item]) -> [Item] {
        let folded = query.trimmingCharacters(in: .whitespaces).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        let kept = all.filter { item in
            isKept(item) && (folded.isEmpty || item.words.contains(folded))
        }
        switch order {
        case .name: return kept.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size: return kept.sorted { (area(of: $0), $1.name) > (area(of: $1), $0.name) }
        }
    }

    /// The room that the card of a spot takes, which orders the store by size.
    private func area(of item: Item) -> CGFloat {
        let size = spot.cardSize(item.id)
        return size.width * size.height
    }

    /// Shows the tip of a control while the pointer rests on it.
    private func tipped(_ text: String, _ view: some View) -> some View {
        view
            .onHover { inside in
                if inside {
                    hovered = text
                } else if hovered == text {
                    hovered = nil
                }
            }
            .anchorPreference(key: TipAnchor.self, value: .bounds) { tip == text ? $0 : nil }
    }

    /// The search, and under it a row for each origin with its picture and the number of its spots.
    private func sidebar(_ all: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            search
                .padding(.bottom, 10)
            ForEach(Origin.allCases) { each in
                let count = each.word.map { word in all.filter { $0.origin == word }.count } ?? all.count
                if count > 0 || each == .all || place == .origin(each) {
                    row(each.symbol, each.rawValue, trailing: "\(count)", tip: each.tip, chosen: place == .origin(each)) { place = .origin(each) }
                }
            }
            Text("Stores")
                .font(Self.caption)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .padding(.horizontal, 10)
                .padding(.top, 12)
                .padding(.bottom, 2)
            ForEach(folders) { folder in
                row(
                    folder.isFound ? "folder" : "questionmark.folder", folder.name,
                    trailing: folder.isFound ? "\(all.filter { $0.store == folder.id }.count)" : "Not Found",
                    tip: folder.isFound ? "Show the spots of \(folder.name)" : "Openspot cannot find \(folder.id)",
                    chosen: place == .store(folder.id), dimmed: !folder.isFound
                ) { place = .store(folder.id) }
                .contextMenu {
                    if folder.isFound { Button("Show in Finder") { openURL(URL(fileURLWithPath: folder.id, isDirectory: true)) } }
                    if !folder.isBuiltIn { Button("Remove Store") { send("remove:\(folder.id)") } }
                }
            }
            row("plus", "Add Store…", tip: "Add a folder of spots as a store", dimmed: true) { send("add") }
            if !folders.contains(where: { !$0.isBuiltIn }) {
                Text("A store is a folder of spots, such as a repo you cloned or a folder a friend shared. Its spots show here, ready to get.")
                    .font(Self.caption)
                    .foregroundStyle(spot.ink.opacity(spot.secondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding([.leading, .top, .bottom], spot.inset)
        .frame(width: sidebarWidth + spot.inset)
        .padding(.trailing, spot.columnGap)
    }

    /// A field whose whole fill takes a click, whose Esc clears it, and whose cross clears it too.
    private var search: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(spot.ink.opacity(spot.secondary))
            TextField("Search spots", text: $query)
                .textFieldStyle(.plain)
                .onExitCommand { query = "" }
            if !query.isEmpty {
                tipped("Clear the search", Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(spot.ink.opacity(spot.secondary))
                    .contentShape(Circle())
                    .onTapGesture { query = "" }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Clear the search"))
            }
        }
        .font(Self.text)
        .padding(.horizontal, 10)
        .frame(height: Self.line)
        .background(spot.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// A row of the sidebar: a picture, a title and a trailing word, filled while it is the chosen one, which a click presses.
    private func row(_ symbol: String, _ title: String, trailing: String = "", tip: String, chosen: Bool = false, dimmed: Bool = false, action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return tipped(tip, HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .frame(width: 20)
            Text(title)
                .font(Self.text)
                .foregroundStyle(spot.ink.opacity(dimmed ? spot.secondary : 1))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(trailing)
                .font(Self.caption)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
        }
        .padding(.horizontal, 10)
        .frame(height: Self.line)
        .background(chosen ? spot.ink.opacity(0.1) : .clear, in: shape)
        .contentShape(shape)
        .onTapGesture(perform: action)
        .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton))
    }

    /// What shows for a store whose folder is gone: why, and the two steps that fix it.
    private func missing(_ folder: Folder) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .padding(.bottom, 4)
            Text("Folder Not Found")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(spot.ink)
            Text("Openspot cannot find \(folder.id). Locate the folder, or remove the store. The spots you got from it stay.")
                .font(Self.text)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                Button("Remove") { send("remove:\(folder.id)") }
                Button("Locate…") { send("locate:\(folder.id)") }
                    .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .disabled(pending != nil)
            .padding(.top, 6)
        }
        .padding(spot.inset * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The groups of cards, which scroll to the edges of the window and are cut there.
    private func gallery(_ items: [Item]) -> some View {
        let groups = [
            ("Get more spots", items.filter { $0.state == "get" }),
            ("Yours to publish", items.filter { $0.state == "publish" }),
            ("Added", items.filter { $0.state == "added" })
        ].filter { !$0.1.isEmpty }
        return ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(Array(groups.enumerated()), id: \.element.0) { index, group in
                    if index > 0 {
                        Rectangle()
                            .fill(spot.ink.opacity(0.1))
                            .frame(height: 1)
                    }
                    section(group.0, group.1)
                }
            }
            .padding([.trailing, .top, .bottom], spot.inset)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, _ in
            hovered = nil
        }
    }

    /// What shows when no spot is kept: a picture, why, and the step that brings spots back.
    private var empty: some View {
        let isSearch = !query.trimmingCharacters(in: .whitespaces).isEmpty
        let folder = chosenFolder
        let origin = if case .origin(let origin) = place { origin } else { Origin.all }
        return VStack(spacing: 8) {
            Image(systemName: isSearch ? "magnifyingglass" : folder == nil ? origin.symbol : "folder")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .padding(.bottom, 4)
            Text(isSearch ? "No Spots Match “\(query)”" : "No Spots Here")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(spot.ink)
            Text(isSearch ? "Check the spelling, or try other words." : folder.map { "You have each spot of \($0.name)." } ?? (origin == .all ? "The store has no spots yet." : "Nothing is in \(origin.rawValue) yet."))
                .font(Self.text)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .multilineTextAlignment(.center)
            if isSearch {
                Button("Clear Search") { query = "" }
                    .padding(.top, 6)
            } else if place != .origin(.all) {
                Button("Show All Spots") { place = .origin(.all) }
                    .padding(.top, 6)
            }
        }
        .padding(spot.inset * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The hint of what a card does, the order of the cards and Done, which closes the store.
    private var footer: some View {
        HStack(spacing: 12) {
            Text(hint)
                .font(Self.text)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            tipped("Order the cards of each group", Picker("Sort", selection: $order) {
                ForEach(Order.allCases) { Text("By \($0.rawValue)").tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .controlSize(.large)
            .fixedSize())
            tipped("Close the store", Button("Done") { spot.close() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large))
        }
        .padding([.trailing, .bottom], spot.inset)
        .padding(.top, spot.rowGap)
    }

    /// The footer's line, which says where the spots of the chosen store come from, and what a card does.
    private var hint: String {
        guard let folder = chosenFolder else {
            return "Click a spot to read about it and try it. The plus adds it to your grid."
        }
        if folder.isBuiltIn { return "Examples that come with Openspot. The plus adds one to your grid." }
        if !folder.isFound { return "The folder of \(folder.name) moved or was deleted." }
        return "From \((folder.id as NSString).abbreviatingWithTildeInPath). The plus copies a spot into your spots, and the folder stays as it is."
    }

    /// A group of cards under its title, whose line matches the search field's, so that both columns start on one line.
    private func section(_ title: String, _ list: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(Self.heading)
                .foregroundStyle(spot.ink.opacity(spot.secondary))
                .frame(height: Self.line)
            Flow(gap: spot.columnGap, line: spot.rowGap) {
                ForEach(list) { tile($0) }
            }
        }
    }

    /// A card with its corner control, which a click opens to its page.
    private func tile(_ item: Item) -> some View {
        let size = spot.cardSize(item.id)
        return tipped("Read about \(item.name)", spot.card(item.id)
            .frame(width: size.width, height: size.height)
            .contentShape(Rectangle())
            .onTapGesture { open(item) })
            .overlay(alignment: .topLeading) { control(item) }
    }

    /// Opens the sheet of a spot, and asks the store for its readme the first time.
    private func open(_ item: Item) {
        hovered = nil
        isTrying = false
        opened = item.id
        if readmes[item.id] == nil { spot.send("readme:\(item.id)") }
    }

    /// The sheet of a spot: its card, name and description, then its readme, or its sheet with sample data while the person
    /// tries it, and at the bottom Close and what its button does.
    private func about(_ item: Item) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                let size = spot.cardSize(item.id)
                spot.card(item.id)
                    .frame(width: size.width, height: size.height)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 22, weight: .semibold))
                    if !item.detail.isEmpty {
                        Text(item.detail)
                            .font(Self.text)
                            .foregroundStyle(.secondary)
                    }
                    Text(folders.first { $0.id == item.store }.map { "From \($0.name)" } ?? Item.label(of: item.origin))
                        .font(Self.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if item.hasSample {
                    Picker("Show", selection: $isTrying) {
                        Text("About").tag(false)
                        Text("Try").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .help("Read about \(item.name), or try it with sample data")
                }
            }
            .padding(20)
            Divider()
            Group {
                if isTrying {
                    ScrollView {
                        VStack(spacing: 10) {
                            spot.sheet(item.id)
                            Text("Sample data. Clicks here run nothing and change nothing on your Mac.")
                                .font(Self.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    ScrollView {
                        readme(item)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            Divider()
            HStack(spacing: 12) {
                Spacer(minLength: 0)
                Button("Close") { opened = nil }
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)
                step(item)
            }
            .padding(20)
        }
        .frame(width: 600, height: 640)
    }

    /// What the button of a spot's sheet does: get it, publish your changes, or nothing once you have it. While its call runs,
    /// the button says so.
    @ViewBuilder
    private func step(_ item: Item) -> some View {
        let running = pending
        switch item.state {
        case "get":
            Button(running == "get:\(item.id)" ? "Getting…" : "Get") { send("get:\(item.id)") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(running != nil)
                .help("Add \(item.name) to your grid")
        case "publish":
            Button(running == "publish:\(item.id)" ? "Publishing…" : "Publish") { send("publish:\(item.id)") }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(running != nil)
                .help("Publish the changes of \(item.name)")
        default:
            Label("Added", systemImage: "checkmark")
                .font(Self.text.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    /// Calls the store, and keeps the call until the store answers.
    private func send(_ call: String) {
        pending = call
        spot.send(call)
    }

    /// The readme of a spot, with its headings in bold, or a line that says it has none once the store has answered.
    private func readme(_ item: Item) -> some View {
        let lines = readmes[item.id] ?? []
        return VStack(alignment: .leading, spacing: 6) {
            if lines.isEmpty, readmes[item.id] != nil {
                Text("\(item.name) has no readme yet.")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                switch line {
                case .heading(let text):
                    Text(text)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.top, 6)
                case .text(let text):
                    Text(text)
                case .media(let source, let caption):
                    VStack(alignment: .leading, spacing: 4) {
                        spot.media(source)
                        if !caption.isEmpty {
                            Text(caption)
                                .font(Self.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .font(Self.text)
        .textSelection(.enabled)
    }

    /// The control on the top left rim of a card, as on the cards of Edit Spots: a plus that gets a spot you lack, an up
    /// arrow that publishes your own spot's changes, and none on a spot you have.
    @ViewBuilder
    private func control(_ item: Item) -> some View {
        switch item.state {
        case "get": corner("plus", label: "Add \(item.name) to your grid", item: item) { send("get:\(item.id)") }
        case "publish": corner("arrow.up", label: "Publish the changes of \(item.name)", item: item) { send("publish:\(item.id)") }
        default: EmptyView()
        }
    }

    private func corner(_ symbol: String, label: String, item: Item, action: @escaping () -> Void) -> some View {
        tipped(label, spot.cornerButton(symbol, label: label, card: item.id, action: action))
    }

    /// A small round control on the rim of a card's top left corner, which a click presses.
}

/// Lays its views in rows that wrap at the width it gets, each row as tall as its tallest view.
private struct Flow: Layout {
    let gap: CGFloat
    let line: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let places = place(subviews, in: width)
        return CGSize(width: proposal.width ?? places.map(\.maxX).max() ?? 0, height: places.map(\.maxY).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (view, rect) in zip(subviews, place(subviews, in: bounds.width)) {
            view.place(at: CGPoint(x: bounds.minX + rect.minX, y: bounds.minY + rect.minY), proposal: ProposedViewSize(rect.size))
        }
    }

    private func place(_ subviews: Subviews, in width: CGFloat) -> [CGRect] {
        var rects: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, height: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width + 0.5 {
                x = 0
                y += height + line
                height = 0
            }
            rects.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + gap
            height = max(height, size.height)
        }
        return rects
    }
}
