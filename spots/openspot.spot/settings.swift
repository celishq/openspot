import AppKit
import SwiftUI

/// The Settings window: a sidebar with the search and its sections, and the page of the chosen one, drawn from the records
/// that settings.sh prints. Each change goes back to the script as words split by tabs, which run one `openspot` call, and
/// the script answers with the records again.
struct SpotView: View {
    let spot: SpotInput
    @State private var book = Book()
    @State private var page = Page.access
    @State private var back: [Page] = []
    @State private var forward: [Page] = []
    @State private var query = ""
    @State private var isFolded = true
    @State private var isAboutShown = false
    @State private var recording: String?
    @State private var pending: [String: String] = [:]
    @State private var drafts: [String: String] = [:]
    @State private var target: String?
    @State private var step: AccountStep?
    @State private var handle = ""
    @State private var phrase = ""
    @State private var words: [String] = []
    @State private var check: [Int] = []
    @State private var choices: [[String]] = []
    @State private var picks: [Int: String] = [:]
    @State private var failure: String?
    @FocusState private var isListening: Bool
    @Environment(\.colorScheme) private var scheme

    /// A section of the sidebar.
    private enum Section: String, CaseIterable, Identifiable {
        case access = "Access", spots = "Spots", keys = "Keys", look = "Look", account = "Account", general = "General", developer = "Developer"

        var id: Self { self }

        var symbol: String {
            switch self {
            case .access: "checkmark.shield"
            case .spots: "square.grid.2x2"
            case .keys: "keyboard"
            case .look: "circle.lefthalf.filled"
            case .account: "person.crop.circle"
            case .general: "gearshape"
            case .developer: "chevron.left.forwardslash.chevron.right"
            }
        }

        var color: Color {
            switch self {
            case .access: .blue
            case .spots: .purple
            case .keys: .gray
            case .look: Color(white: 0.15)
            case .account: .indigo
            case .general: .gray
            case .developer: Color(white: 0.3)
            }
        }

        var page: Page {
            switch self {
            case .access: .access
            case .spots: .spots
            case .keys: .keys
            case .look: .look
            case .account: .account
            case .general: .general
            case .developer: .developer
            }
        }
    }

    /// What the window shows: a section, the page of one macOS access, or the page of one spot.
    private enum Page: Hashable {
        case access, accessOf(String), spots, spotOf(String), keys, look, account, general, developer

        var section: Section {
            switch self {
            case .access, .accessOf: .access
            case .spots, .spotOf: .spots
            case .keys: .keys
            case .look: .look
            case .account: .account
            case .general: .general
            case .developer: .developer
            }
        }
    }

    /// One macOS access: its id, its name, whether macOS gives it, the spots that need it, and those that may.
    private struct Access: Identifiable {
        let id: String
        let title: String
        let state: String
        let spots: [String]
        let maybe: [String]

        var isAllowed: Bool { state == "allowed" }

        var symbol: String {
            switch id {
            case "accessibility": "accessibility"
            case "automation": "gearshape.2.fill"
            case "screen": "rectangle.dashed.badge.record"
            case "calendars": "calendar"
            case "reminders": "list.bullet"
            case "camera": "camera.fill"
            case "microphone": "mic.fill"
            case "input": "keyboard.fill"
            default: "cup.and.saucer.fill"
            }
        }

        var color: Color {
            switch id {
            case "accessibility": Color(red: 0.10, green: 0.49, blue: 0.96)
            case "automation": Color(red: 0.56, green: 0.56, blue: 0.58)
            case "screen": Color(red: 0.65, green: 0.31, blue: 0.94)
            case "calendars": Color(red: 1, green: 0.23, blue: 0.19)
            case "reminders": Color(red: 1, green: 0.58, blue: 0)
            case "camera": Color(red: 0.19, green: 0.64, blue: 0.42)
            case "microphone": Color(red: 1, green: 0.18, blue: 0.33)
            case "input": Color(red: 0.39, green: 0.39, blue: 0.40)
            default: Color(red: 0.96, green: 0.71, blue: 0)
            }
        }

        /// What Openspot does with it, in one sentence.
        var purpose: String {
            switch id {
            case "accessibility": "Reads what you select, and types and moves windows in the front app."
            case "automation": "Reads the front tab of a browser and what Finder has selected."
            case "screen": "Takes a picture or a recording of the screen."
            case "calendars": "Reads your events, and adds the ones you ask for."
            case "reminders": "Reads your reminders, and adds and ticks the ones you ask for."
            case "camera": "Films you beside a screen recording that asks for it."
            case "microphone": "Records your voice with a screen recording that asks for it."
            case "input": "Records each key and click with a screen recording that asks for it."
            default: "Keeps the Mac awake with its lid closed."
            }
        }

        var word: String {
            switch state {
            case "allowed": "Allowed"
            case "denied": "Not allowed"
            case "unasked": "Not asked"
            default: "Unknown"
            }
        }

        var wordColor: Color {
            switch state {
            case "denied": .red
            case "unasked": .orange
            default: .secondary
            }
        }

        /// The state, said as a sentence for the header of its page.
        var sentence: String {
            switch state {
            case "allowed": "macOS gives it to Openspot."
            case "denied": "macOS doesn’t give it to Openspot. Allow… opens its switch in System Settings."
            case "unasked": "macOS hasn’t asked you yet."
            default: "Openspot can’t read whether macOS gives it."
            }
        }
    }

    /// One spot: its id, name, icon, line, state, uses, the macOS accesses it lacks, the uses it was refused, and the
    /// accesses that the calls of each use need or may need.
    private struct Entry: Identifiable {
        let id: String
        let title: String
        let icon: String
        let detail: String
        let state: String
        let uses: [String]
        let needs: [String]
        let refused: [String]
        let access: [String: [String]]
        let maybe: [String: [String]]
        let words: String

        var lacks: Bool { state == "access" || state == "review" }
        var isOff: Bool { state == "off" }

        var word: String {
            switch state {
            case "access": "Needs access"
            case "review": "Needs review"
            case "off": "Off"
            default: "Ready"
            }
        }
    }

    /// One row of `openspot setting list`.
    private struct Row: Identifiable {
        let id: String
        let spot: String
        let name: String
        let key: String
        let title: String
        let value: String
        let form: String
        let section: String
        let detail: String
        let words: String
        let options: [String]
        let fallback: String
    }

    /// The colours of a theme in one appearance.
    private struct Swatch {
        let background: Color
        let ink: Color
        let accent: Color
    }

    /// A theme: its name, whether it is in use or built in, and its colours.
    private struct Look: Identifiable {
        let id: String
        let isUsed: Bool
        let isBuiltIn: Bool
        let dark: Swatch
        let light: Swatch
    }

    /// An id for a list of plain words.
    private struct Named: Identifiable {
        let id: String
    }

    /// The guided grant that runs: the spot, each macOS access it walks in a row, the one it waits on, the ones done, where
    /// the switch of that one is in System Settings, and whether Openspot must start again to use it.
    private struct Grant {
        let spot: String
        let steps: [String]
        let step: String
        let done: Set<String>
        let place: String
        let restarts: Bool
    }

    /// Every record of the script, read once for each of its answers.
    private struct Book {
        var accesses: [Access] = []
        var entries: [Entry] = []
        var rows: [Row] = []
        var looks: [Look] = []
        var account: [(String, String)] = []
        var grant: Grant?
        var images: [String: NSImage] = [:]
        var symbols: Set<String> = []
        var clashes: [[Row]] = []
        var clashing: Set<String> = []

        init() {}

        init(_ items: SpotItems) {
            let fold = { (text: String) in text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
            let list = { (text: String?) in (text ?? "").split(separator: ",").map(String.init) }
            for item in items {
                let id = item.id
                switch item["kind"] {
                case "access":
                    accesses.append(Access(id: String(id.dropFirst(7)), title: item["title"] ?? id, state: item["access"] ?? "unknown", spots: list(item["spots"]), maybe: list(item["maybe"])))
                case "spot":
                    let spot = String(id.dropFirst(5))
                    guard !entries.contains(where: { $0.id == spot }) else { continue }
                    let uses = list(item["uses"])
                    let icon = item["icon"] ?? "app"
                    let title = item["title"] ?? spot
                    entries.append(Entry(
                        id: spot, title: title, icon: icon, detail: item["detail"] ?? "", state: item["state"] ?? "ready", uses: uses,
                        needs: list(item["needs"]), refused: list(item["refused"]),
                        access: Dictionary(uniqueKeysWithValues: uses.map { ($0, list(item["access.\($0)"])) }),
                        maybe: Dictionary(uniqueKeysWithValues: uses.map { ($0, list(item["maybe.\($0)"])) }),
                        words: fold(title + " " + (item["detail"] ?? ""))
                    ))
                    if icon.hasPrefix("/") {
                        images[spot] = Self.image(at: icon)
                    } else if NSImage(systemSymbolName: icon, accessibilityDescription: nil) != nil {
                        symbols.insert(spot)
                    }
                case "row":
                    let title = item["title"] ?? ""
                    rows.append(Row(
                        id: String(id.dropFirst(4)), spot: item["spot"] ?? "", name: item["name"] ?? item["spot"] ?? "", key: item["key"] ?? "", title: title, value: item["value"] ?? "",
                        form: item["form"] ?? "", section: item["section"] ?? "", detail: item["detail"] ?? "", words: fold(title + " " + (item["detail"] ?? "")),
                        options: list(item["options"]), fallback: item["default"] ?? ""
                    ))
                case "theme":
                    let swatch = { (name: String) in
                        Swatch(background: Self.color(item["\(name).background"]), ink: Self.color(item["\(name).ink"]), accent: Self.color(item["\(name).accent"]))
                    }
                    looks.append(Look(id: String(id.dropFirst(6)), isUsed: item["used"] == "true", isBuiltIn: item["builtin"] == "true", dark: swatch("dark"), light: swatch("light")))
                case "grant":
                    grant = Grant(
                        spot: item["spot"] ?? "", steps: list(item["steps"]), step: item["step"] ?? "", done: Set(list(item["done"])),
                        place: item["place"] ?? "", restarts: item["restart"] == "true"
                    )
                case "account":
                    account = ["signedIn", "handle", "npub", "since", "backedUp", "sync"].compactMap { key in item[key].map { (key, $0) } }
                default:
                    continue
                }
            }
            entries.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            let keyed = rows.filter { $0.form == "key" && !$0.value.isEmpty && $0.value != "none" }
            clashes = Dictionary(grouping: keyed) { Self.normal($0.value) }.values.filter { $0.count > 1 }.sorted { $0[0].value < $1[0].value }
            clashing = Set(clashes.flatMap { $0.map(\.id) })
        }

        func entry(_ id: String) -> Entry? {
            entries.first { $0.id == id }
        }

        func access(_ id: String) -> Access? {
            accesses.first { $0.id == id }
        }

        func title(ofSpot id: String) -> String {
            entry(id)?.title ?? rows.first { $0.spot == id }?.name ?? id
        }

        /// The spots that can't run, the ones that need you first.
        var waiting: [Entry] {
            entries.filter(\.lacks)
        }

        private static func normal(_ key: String) -> String {
            let words = key.lowercased().split(separator: "+").map(String.init)
            return (words.dropLast().sorted() + words.suffix(1)).joined(separator: "+")
        }

        private static func image(at path: String) -> NSImage {
            let pictures = ["png", "jpg", "jpeg", "svg", "pdf", "tiff", "heic", "gif", "icns"]
            guard pictures.contains((path as NSString).pathExtension.lowercased()), let image = NSImage(contentsOfFile: path) else {
                return NSWorkspace.shared.icon(forFile: path)
            }
            return image
        }

        static func color(_ text: String?) -> Color {
            switch text {
            case "accent", nil: return .accentColor
            case "green": return .green
            case "orange": return .orange
            case "red": return .red
            case let hex?:
                let digits = hex.dropFirst()
                guard hex.hasPrefix("#"), [6, 8].contains(digits.count), let value = UInt32(digits, radix: 16) else { return .accentColor }
                let full = digits.count == 6 ? value << 8 | 0xFF : value
                let part = { (shift: UInt32) in Double(full >> shift & 0xFF) / 255 }
                return Color(red: part(24), green: part(16), blue: part(8), opacity: part(0))
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(spacing: 0) {
                titleBar
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            content
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: target) {
                        guard let target else { return }
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
                Divider()
                footer
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        .navigationSplitViewStyle(.balanced)
        .focusable()
        .focusEffectDisabled()
        .focused($isListening)
        .onKeyPress(phases: .down) { press in record(press) }
        .overlay { book.grant.map(grantSheet) }
        .sheet(isPresented: $isAboutShown) { about }
        .sheet(item: $step) { accountSheet($0) }
        .onChange(of: spot.answers, initial: true) {
            book = Book(spot.items)
            pending = [:]
            if let at = spot["at"] { land(at) }
        }
    }

    // MARK: The frame

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search", text: $query)
                    .textFieldStyle(.plain)
                    .onExitCommand { query = "" }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Clear the search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(.quaternary.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(.separator.opacity(0.6)))
            .padding(.horizontal, 10)
            .padding(.top, 2)
            .padding(.bottom, 6)
            List(selection: chosen) {
                ForEach(Section.allCases) { section in
                    let count = section == .access ? book.waiting.count : 0
                    HStack(spacing: 8) {
                        tile(section.symbol, section.color, size: 20)
                        Text(section.rawValue)
                        Spacer(minLength: 0)
                        if count > 0 {
                            Text("\(count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 18, minHeight: 18)
                                .background(Color.red, in: Circle())
                        }
                    }
                    .tag(section)
                }
            }
            .listStyle(.sidebar)
        }
    }

    private var chosen: Binding<Section?> {
        Binding(
            get: { query.isEmpty ? page.section : nil },
            set: { if let section = $0 { open(section) } }
        )
    }

    private var titleBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 0) {
                Button { goBack() } label: { Image(systemName: "chevron.left").frame(width: 30, height: 26) }
                    .disabled(back.isEmpty)
                    .help("Back")
                Divider().frame(height: 16)
                Button { goForward() } label: { Image(systemName: "chevron.right").frame(width: 30, height: 26) }
                    .disabled(forward.isEmpty)
                    .help("Forward")
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 4)
            .background(.background.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(.separator.opacity(0.6)))
            Text(query.isEmpty ? title(of: page) : "Search")
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Text(hint)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Done") { spot.close() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private var hint: String {
        if recording != nil { return "Type the new key. Esc keeps the old one, and ⌫ removes it." }
        if !query.isEmpty { return "Click a row to open its page." }
        switch page {
        case .access: return "Each spot works with all it declares, or not at all."
        case .accessOf: return "Turn it off in System Settings, and every spot here stops."
        case .spots: return "Click a spot to see what it uses."
        case .spotOf: return "A spot gets only the uses it declares."
        case .keys: return "Click a key to record a new one."
        case .look: return "A theme changes only the look."
        case .account: return "The account signs what you publish."
        case .general: return "The settings of Openspot itself."
        case .developer: return "Tools for those who build spots."
        }
    }

    @ViewBuilder
    private var content: some View {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty {
            results
        } else {
            switch page {
            case .access: accessPage
            case .accessOf(let id): book.access(id).map { accessPage(of: $0) }
            case .spots: spotsPage
            case .spotOf(let id): book.entry(id).map { spotPage(of: $0) }
            case .keys: keysPage
            case .look: lookPage
            case .account: accountPage
            case .general: rowsPage("General", "The keys that open Openspot, and how it starts.", section: "general")
            case .developer: rowsPage("Developer", "For those who build spots and themes.", section: "developer")
            }
        }
    }

    // MARK: Access

    private var accessPage: some View {
        let needed = book.accesses.filter { !$0.spots.isEmpty }
        let rest = book.accesses.filter { $0.spots.isEmpty }
        return Group {
            header(tile("checkmark.shield.fill", .blue, size: 52), "Access", "macOS gives Openspot each access once, and Openspot passes it only to the spots that need it. A spot runs with everything it needs, or not at all.") {
                Button("About access…") { isAboutShown = true }
                    .buttonStyle(.link)
            }
            if !book.waiting.isEmpty {
                group("Needs you") {
                    lines(book.waiting) { entry in
                        row(open: .spotOf(entry.id)) {
                            spotIcon(entry, size: 28)
                            titled(entry.title, lack(of: entry))
                            Spacer(minLength: 8)
                            fix(entry)
                        }
                    }
                }
            }
            group("macOS gives Openspot") {
                lines(needed) { access in
                    row(open: .accessOf(access.id)) {
                        tile(access.symbol, access.color, size: 28)
                        titled(access.title, access.spots.map(book.title(ofSpot:)).joined(separator: ", "))
                        Spacer(minLength: 8)
                        Text(access.word).foregroundStyle(access.wordColor)
                        chevron
                    }
                }
                if !rest.isEmpty {
                    if !needed.isEmpty { Divider().padding(.leading, 12) }
                    row(action: { isFolded.toggle() }) {
                        HStack(spacing: -6) {
                            ForEach(rest.prefix(4)) { tile($0.symbol, $0.color, size: 22) }
                        }
                        titled(rest.count == 1 ? "1 more" : "\(rest.count) more", rest.map(\.title).joined(separator: ", "))
                        Spacer(minLength: 8)
                        Text("No spot needs them").foregroundStyle(.secondary)
                        Image(systemName: isFolded ? "chevron.down" : "chevron.up")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    if !isFolded {
                        lines(rest, first: true) { access in
                            row(open: .accessOf(access.id)) {
                                tile(access.symbol, access.color, size: 28)
                                titled(access.title, access.maybe.isEmpty ? "" : "Asked at first use by " + access.maybe.map(book.title(ofSpot:)).joined(separator: ", "))
                                Spacer(minLength: 8)
                                Text(access.word).foregroundStyle(.secondary)
                                chevron
                            }
                        }
                    }
                }
            }
        }
    }

    private func accessPage(of access: Access) -> some View {
        let needers = access.spots.compactMap(book.entry)
        let maybes = access.maybe.compactMap(book.entry)
        return Group {
            header(tile(access.symbol, access.color, size: 52), access.title, "\(access.purpose) \(access.sentence)") {
                if !access.isAllowed {
                    Button("Allow…") { send("ask", access.id) }
                        .controlSize(.large)
                        .padding(.top, 4)
                }
            }
            group("Spots that need it") {
                if needers.isEmpty {
                    plain("No spot that is on needs it.")
                }
                lines(needers) { entry in
                    spotLine(entry)
                }
            }
            if !maybes.isEmpty {
                group("Spots that may ask for it") {
                    lines(maybes) { entry in
                        spotLine(entry)
                    }
                }
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About access")
                .font(.title2.weight(.semibold))
            Text("macOS asks you once for each access, such as Screen Recording, and gives it to Openspot as a whole. Openspot then passes it on, one spot at a time.")
            Text("A spot gets only the uses it declares in its spot.toml, which you approved when you added it. A call past them is refused, and the spot asks for your review.")
            Text("A spot is Ready when macOS gives Openspot every access that its calls need, and Needs access when one is missing. An access that only some calls need, such as the camera for a recording, is asked for at its first use.")
            Text("To take an access away from one spot, turn the spot off. To take it from every spot, turn it off in System Settings.")
            HStack {
                Spacer()
                Button("Done") { isAboutShown = false }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 6)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(width: 460)
    }

    // MARK: The guided grant

    /// The step sheet of the guided grant: each access in a row, the one it waits on with the switch to turn on in System
    /// Settings, and Not now. Openspot moves it on once macOS gives the access.
    private func grantSheet(_ grant: Grant) -> some View {
        let name = book.entry(grant.spot)?.title ?? grant.spot
        return ZStack(alignment: .top) {
            Color.black.opacity(0.18)
                .ignoresSafeArea()
                .contentShape(Rectangle())
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(grant.steps.count == 1 ? "\(name) needs \(names(grant.steps))" : "\(name) needs \(grant.steps.count) accesses")
                        .font(.title3.weight(.semibold))
                    Text(grant.steps.count == 1 ? "Turn it on in System Settings. This moves on by itself." : "Turn each on in System Settings. This moves on by itself.")
                        .foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(grant.steps.enumerated()), id: \.element) { index, id in
                        if index > 0 { Divider().padding(.vertical, 10) }
                        grantStep(id, number: index + 1, of: grant)
                    }
                }
                HStack(spacing: 10) {
                    Spacer()
                    Button("Not now") { send("grant", "end") }
                        .keyboardShortcut(.cancelAction)
                    if grant.restarts {
                        Button("Restart Openspot") { send("restart") }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Open System Settings") { send("pane", grant.step) }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .controlSize(.large)
            }
            .padding(22)
            .frame(width: 460, alignment: .leading)
            .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
            .padding(.top, 52)
        }
    }

    /// One step of the grant: a number that turns into a tick once macOS gives the access, its name and what it does, and
    /// for the step it waits on, the switch to find.
    private func grantStep(_ id: String, number: Int, of grant: Grant) -> some View {
        let access = book.access(id)
        let isDone = grant.done.contains(id)
        let isNow = id == grant.step
        return HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(isDone ? Color.green : isNow ? Color.accentColor : Color.primary.opacity(0.12))
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                } else {
                    Text("\(number)").font(.system(size: 12, weight: .semibold)).foregroundStyle(isNow ? Color.white : Color.secondary)
                }
            }
            .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(access?.title ?? id)
                        .fontWeight(.semibold)
                        .foregroundStyle(isNow ? Color.primary : Color.secondary)
                    if isNow {
                        Text(access?.purpose ?? "")
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                if isNow {
                    systemSwitch(grant.place)
                    if grant.restarts {
                        Text("Openspot must start again to use it. Turn it on, then restart; Settings opens here again.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    /// The row of Openspot as System Settings draws it, with its switch still off, and where to find it.
    private func systemSwitch(_ place: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 22, height: 22)
                Text("Openspot")
                Spacer(minLength: 8)
                Toggle("", isOn: .constant(false))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
                    .padding(3)
                    .overlay(Capsule().strokeBorder(Color.accentColor, lineWidth: 1.5))
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text("System Settings › \(place)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("In System Settings, \(place), turn on Openspot")
    }

    // MARK: Spots

    private var spotsPage: some View {
        Group {
            heading("Spots", "Each spot that comes with Openspot or that you added, and whether it can run.")
            group(nil) {
                lines(book.entries) { entry in
                    spotLine(entry, detail: entry.detail)
                }
            }
        }
    }

    private func spotPage(of entry: Entry) -> some View {
        let rows = book.rows.filter { $0.spot == entry.id }
        let keys = rows.filter { $0.form == "key" }
        let fields = rows.filter { ["field", "text", "secret", "choice"].contains($0.form) }
        let toggles = rows.filter { $0.form == "toggle" }
        let size = spot.cardSize(entry.id)
        return Group {
            HStack(alignment: .center, spacing: 14) {
                spotIcon(entry, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.title)
                        .font(.title2.weight(.semibold))
                    if !entry.detail.isEmpty {
                        Text(entry.detail)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 12)
                if !entry.isOff, size.width > 0 {
                    spot.card(entry.id)
                        .frame(width: size.width, height: size.height)
                        .allowsHitTesting(false)
                }
            }
            if entry.lacks || entry.isOff {
                banner(entry)
            }
            group("Uses") {
                if entry.uses.isEmpty {
                    plain("It uses nothing of your Mac.")
                }
                lines(entry.uses.map { Named(id: $0) }) { use in
                    useLine(use.id, of: entry)
                }
            }
            if !keys.isEmpty {
                group("Keys") {
                    lines(keys) { settingLine($0) }
                }
            }
            if !fields.isEmpty {
                group("Settings") {
                    lines(fields) { settingLine($0) }
                }
            }
            if !toggles.isEmpty {
                group("Where it shows") {
                    lines(toggles) { settingLine($0) }
                }
            }
            HStack {
                Spacer()
                if entry.isOff {
                    Button("Turn On") { send("turn", entry.id, "true") }
                } else {
                    Button("Turn Off", role: .destructive) { send("turn", entry.id, "false") }
                }
            }
            .controlSize(.large)
        }
    }

    /// A banner that says why the spot can't run, with the step that fixes it.
    private func banner(_ entry: Entry) -> some View {
        let (title, line): (String, String) = switch entry.state {
        case "off": ("\(entry.title) is off", "It runs again once you turn it on.")
        case "review": ("\(entry.title) needs your review", lack(of: entry))
        default: ("\(entry.title) can’t run yet", "It needs \(names(entry.needs)) from macOS.")
        }
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(line).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if entry.isOff {
                Button("Turn On") { send("turn", entry.id, "true") }
            } else {
                fix(entry)
            }
        }
        .padding(14)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.orange.opacity(0.45), lineWidth: 0.5))
    }

    private func useLine(_ use: String, of entry: Entry) -> some View {
        let accesses = (entry.access[use] ?? []).compactMap(book.access)
        let maybe = (entry.maybe[use] ?? []).compactMap(book.access)
        return HStack(spacing: 10) {
            Text(use)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .overlay(Capsule().strokeBorder(Color.primary.opacity(0.3), lineWidth: 0.5))
            Text(purpose(of: use))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                if accesses.isEmpty {
                    Text("Nothing to grant").foregroundStyle(.tertiary)
                }
                ForEach(accesses) { access in
                    HStack(spacing: 6) {
                        tile(access.symbol, access.color, size: 18)
                        Text(access.title + ": ") + Text(access.word).foregroundColor(access.wordColor)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { go(.accessOf(access.id)) }
                }
                if !maybe.isEmpty {
                    Text("May ask for \(names(maybe.map(\.id)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    // MARK: Keys

    private var keysPage: some View {
        let keys = book.rows.filter { $0.form == "key" }
        return Group {
            heading("Keys", "Every key of Openspot and of its spots.")
            ForEach(Array(book.clashes.enumerated()), id: \.offset) { _, clash in
                VStack(alignment: .leading, spacing: 2) {
                    Text(caps(clash[0].value).joined() + " does \(clash.count == 2 ? "two" : "\(clash.count)") things")
                        .fontWeight(.semibold)
                    Text(clash.map { "\($0.name) · \($0.title)" }.joined(separator: " and ") + ". Change one of them.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.red.opacity(0.45), lineWidth: 0.5))
            }
            group(nil) {
                lines(keys) { row in
                    HStack(spacing: 12) {
                        Text(row.name)
                            .foregroundStyle(.secondary)
                            .frame(width: 150, alignment: .leading)
                            .lineLimit(1)
                        Text(row.title)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        keycaps(row)
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 40)
                    .background(target == row.id ? Color.accentColor.opacity(0.15) : .clear)
                    .id(row.id)
                }
            }
        }
    }

    /// The keycaps of a key row, red when another row has the same key, which a click starts to record.
    private func keycaps(_ row: Row) -> some View {
        let value = pending[row.id] ?? row.value
        let clash = book.clashing.contains(row.id)
        return Button {
            recording = row.id
            isListening = true
        } label: {
            if recording == row.id {
                Text("Type a key…")
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Color.accentColor, lineWidth: 1))
            } else if caps(value).isEmpty {
                Text("Not set").foregroundStyle(.secondary)
            } else {
                HStack(spacing: 3) {
                    ForEach(Array(caps(value).enumerated()), id: \.offset) { _, cap in
                        Text(cap)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(clash ? Color.red : Color.primary)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 22, minHeight: 20)
                            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(clash ? Color.red : Color.primary.opacity(0.3), lineWidth: 0.5))
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .help(recording == row.id ? "Esc keeps the old key" : "Record a new key")
    }

    /// The caps of a key such as `ctrl+option+space`: its modifiers in the order macOS draws them, then its key.
    private func caps(_ key: String) -> [String] {
        guard !key.isEmpty, key != "none" else { return [] }
        var words = key.lowercased().split(separator: "+").map(String.init)
        let name = words.popLast() ?? ""
        let marks = [("ctrl", "⌃"), ("option", "⌥"), ("shift", "⇧"), ("cmd", "⌘")].filter { words.contains($0.0) }.map(\.1)
        let names = ["space": "Space", "return": "↩", "tab": "⇥", "backspace": "⌫", "escape": "Esc", "left": "←", "right": "→", "up": "↑", "down": "↓", "shake": "Shake"]
        return marks + [names[name] ?? (name.count == 1 ? name.uppercased() : name.capitalized)]
    }

    /// The word of `openspot setting set` for a key that the person types.
    private func name(of key: KeyEquivalent) -> String {
        switch key {
        case .space: "space"
        case .return: "return"
        case .tab: "tab"
        case .delete: "backspace"
        case .escape: "escape"
        case .leftArrow: "left"
        case .rightArrow: "right"
        case .upArrow: "up"
        case .downArrow: "down"
        default: String(key.character).lowercased()
        }
    }

    /// Takes the key that the person types while a row records: Esc stops, ⌫ alone takes a spot's key away, and any other
    /// key with ⌘, ⌃ or ⌥ becomes the row's key.
    private func record(_ press: KeyPress) -> KeyPress.Result {
        guard let id = recording, let row = book.rows.first(where: { $0.id == id }) else { return .ignored }
        let name = name(of: press.key)
        let modifiers = [(EventModifiers.command, "cmd"), (EventModifiers.control, "ctrl"), (EventModifiers.option, "option"), (EventModifiers.shift, "shift")]
            .filter { press.modifiers.contains($0.0) }.map(\.1)
        if name == "escape" {
            recording = nil
            return .handled
        }
        if name == "backspace", modifiers.isEmpty {
            recording = nil
            if row.spot != "openspot" { set(row, "") }
            return .handled
        }
        guard modifiers.contains(where: { ["cmd", "ctrl", "option"].contains($0) }) else { return .handled }
        recording = nil
        set(row, (modifiers + [name]).joined(separator: "+"))
        return .handled
    }

    // MARK: Look, Account, General and Developer

    private var lookPage: some View {
        Group {
            heading("Look", "The theme of the panel. Each theme keeps its exact values in its own file.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 18)], spacing: 18) {
                ForEach(book.looks) { look in
                    VStack(spacing: 6) {
                        preview(look)
                        Text(look.id)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(look.isUsed ? "In use" : look.isBuiltIn ? "Built in" : "Yours")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { if !look.isUsed { send("theme", look.id) } }
                    .help(look.isUsed ? "\(look.id) is in use" : "Use \(look.id)")
                }
            }
        }
    }

    /// A small panel in the colours of a theme over a wallpaper, with a ring when it is the one in use.
    private func preview(_ look: Look) -> some View {
        let swatch = scheme == .dark ? look.dark : look.light
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
        return ZStack {
            LinearGradient(
                colors: [Color(red: 0.96, green: 0.36, blue: 0.36), Color(red: 0.55, green: 0.42, blue: 0.95), Color(red: 0.36, green: 0.78, blue: 0.42)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 5) {
                Capsule().fill(swatch.ink.opacity(0.18)).frame(height: 9)
                ForEach(0..<3) { line in
                    HStack(spacing: 5) {
                        ForEach(0..<3) { column in
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(line == 0 && column == 0 ? swatch.accent : swatch.ink.opacity(0.14))
                        }
                    }
                }
            }
            .padding(8)
            .background(swatch.background.opacity(0.88), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.horizontal, 30)
            .padding(.vertical, 14)
        }
        .frame(height: 104)
        .clipShape(shape)
        .overlay(shape.strokeBorder(look.isUsed ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: look.isUsed ? 3 : 0.5))
    }

    private var accountPage: some View {
        let facts = Dictionary(book.account) { first, _ in first }
        let isIn = facts["signedIn"] == "true"
        let rows = book.rows.filter { $0.section == "account" }
        return Group {
            if isIn {
                header(tile("person.crop.circle.fill", .gray, size: 52), "Account", "Your key signs each spot you publish, so people know an update is from you.") {
                    Button("How it works") { step = .how }
                        .buttonStyle(.link)
                }
                group(nil) {
                    lines(["handle", "npub", "since"].filter { facts[$0] != nil }.map { Named(id: $0) }) { fact in
                        HStack {
                            Text(["handle": "Handle", "npub": "Public key", "since": "Since"][fact.id] ?? fact.id)
                            Spacer(minLength: 12)
                            Text(facts[fact.id] ?? "")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .textSelection(.enabled)
                            if fact.id == "npub" {
                                Button("Copy") { copy(facts["npub"] ?? "") }
                            }
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                    }
                }
                group("Backup") {
                    if let sync = facts["sync"] {
                        HStack {
                            titled("Keep in iCloud Keychain", "Your other Macs sign in with it.")
                            Spacer(minLength: 12)
                            Toggle("", isOn: Binding(get: { sync == "true" }, set: { send("sync", $0 ? "on" : "off") }))
                                .toggleStyle(.switch)
                                .labelsHidden()
                                .controlSize(.small)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 40)
                        Divider().padding(.leading, 12)
                    }
                    HStack {
                        titled("Recovery words", "12 words bring your key back on any Mac.")
                        Spacer(minLength: 12)
                        Text(saved(facts).word).foregroundStyle(saved(facts).color)
                        Button("Show My Words…") { step = .words }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                }
                if !rows.isEmpty {
                    group(nil) { lines(rows) { settingLine($0) } }
                }
                HStack {
                    Spacer()
                    Button("Sign Out…") { step = .leave }
                }
                .controlSize(.large)
            } else {
                header(tile("person.crop.circle.fill", .gray, size: 52), "Account", "You need a key to publish. Openspot signs your spots with it, so people know an update is from you.") {
                    HStack(spacing: 10) {
                        Button("Create a New Key…") { step = .handle }
                            .buttonStyle(.borderedProminent)
                        Button("Use My Own Key…") { step = .signIn }
                        Button("How it works") { step = .how }
                            .buttonStyle(.link)
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    /// Puts the public key on the clipboard, and says so.
    private func copy(_ npub: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(npub, forType: .string)
        send("say", "Copied your key")
    }

    /// Whether the recovery words are kept somewhere, said in a word and its colour.
    private func saved(_ facts: [String: String]) -> (word: String, color: Color) {
        if facts["backedUp"] == "true" { return ("Saved", .green) }
        if facts["sync"] == "true" { return ("In iCloud Keychain", .secondary) }
        return ("Not saved yet", .orange)
    }

    // MARK: The steps of the account

    /// A step of the account, shown as a sheet of the window.
    private enum AccountStep: String, Identifiable {
        case how, handle, signIn, words, check, leave

        var id: Self { self }
    }

    @ViewBuilder
    private func accountSheet(_ shown: AccountStep) -> some View {
        let facts = Dictionary(book.account) { first, _ in first }
        VStack(alignment: .leading, spacing: 14) {
            switch shown {
            case .how: howSheet
            case .handle: handleSheet
            case .signIn: signInSheet(isIn: facts["signedIn"] == "true")
            case .words: wordsSheet(isSaved: facts["backedUp"] == "true", isSynced: facts["sync"] == "true")
            case .check: checkSheet
            case .leave: leaveSheet(facts)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(24)
        .frame(width: 460, alignment: .leading)
        .onDisappear(perform: forgetWords)
    }

    private func sheetTitle(_ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(line)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func fact(_ text: String, _ symbol: String, _ color: Color = .secondary) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
    }

    private func buttons<Main: View>(@ViewBuilder _ main: () -> Main) -> some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") { step = nil }
                .keyboardShortcut(.cancelAction)
            main()
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .controlSize(.large)
        .padding(.top, 6)
    }

    private var howSheet: some View {
        Group {
            sheetTitle("How your key works", "Openspot signs each spot you publish with your key. There is no email, password or server.")
            VStack(alignment: .leading, spacing: 10) {
                fact("Shows an update is yours", "checkmark.seal")
                fact("Kept in iCloud Keychain", "icloud")
                fact("12 words bring it back", "list.number")
                fact("Anyone with the words is you", "eye.slash")
                fact("Nobody can reset them", "exclamationmark.triangle", .orange)
            }
            HStack {
                Spacer()
                Button("Done") { step = nil }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, 6)
        }
    }

    private var handleSheet: some View {
        Group {
            sheetTitle("Pick your handle", "It names you on the spots you publish, and in their links.")
            TextField("yourname", text: $handle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(create)
            buttons {
                Button("Create Key", action: create)
                    .disabled(handle.isEmpty)
            }
        }
    }

    private func create() {
        guard !handle.isEmpty else { return }
        send("new", handle)
        step = nil
    }

    private func signInSheet(isIn: Bool) -> some View {
        let line = spot.secrets?.line(of: phrase) ?? [:]
        let canSign = line["detail"] != nil
        return Group {
            sheetTitle("Use your own key", "Type your 12 words, or an nsec. Openspot asks for Touch ID before it signs in.")
            TextEditor(text: $phrase)
                .font(.body.monospaced())
                .frame(height: 76)
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            if let failure {
                fact(failure, "exclamationmark.triangle", .red)
            } else if let title = line["title"] {
                HStack(spacing: 6) {
                    fact(title, line["icon"] ?? "info.circle", tone(line["tone"]))
                    if let detail = line["detail"] {
                        Text(detail).foregroundStyle(.secondary).font(.body.monospaced())
                    }
                }
            }
            buttons {
                Button("Sign In") { signIn() }
                    .disabled(!canSign)
            }
        }
        .onChange(of: phrase) { failure = nil }
    }

    private func tone(_ word: String?) -> Color {
        switch word {
        case "good": .green
        case "warn": .orange
        case "bad": .red
        default: .secondary
        }
    }

    private func signIn() {
        let typed = phrase
        guard let secrets = spot.secrets else { return failure = SpotSecrets.missing }
        Task {
            if let failure = await secrets.signIn(typed) {
                self.failure = failure
            } else {
                step = nil
                send("say", "Signed in")
            }
        }
    }

    private func wordsSheet(isSaved: Bool, isSynced: Bool) -> some View {
        Group {
            sheetTitle("Write them down", "In this order. Anyone with them is you, and nobody can reset them.")
            if let failure {
                fact(failure, "exclamationmark.triangle", .red)
            }
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                ForEach(0..<(words.count + 2) / 3, id: \.self) { line in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            let index = line * 3 + column
                            if index < words.count {
                                HStack(spacing: 6) {
                                    Text("\(index + 1)").foregroundStyle(.secondary).monospacedDigit().frame(width: 18, alignment: .trailing)
                                    Text(words[index]).font(.body.monospaced())
                                }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            HStack(spacing: 10) {
                Spacer()
                Button(isSaved ? "Done" : "Later") { step = nil }
                    .keyboardShortcut(.cancelAction)
                if !words.isEmpty, !isSaved {
                    Button("I Wrote Them Down") { wrote(isSynced: isSynced) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .controlSize(.large)
            .padding(.top, 6)
        }
        .task { await reveal() }
    }

    private func reveal() async {
        guard words.isEmpty, let secrets = spot.secrets else { return }
        let shown = await secrets.words()
        words = shown.words
        failure = shown.failure
    }

    private func wrote(isSynced: Bool) {
        words = []
        if isSynced { return step = nil }
        let places = Array((1...12).shuffled().prefix(2)).sorted()
        check = places
        choices = spot.secrets?.choices(at: places) ?? []
        picks = [:]
        failure = nil
        step = .check
    }

    private var checkSheet: some View {
        Group {
            sheetTitle("Pick each word you wrote", "Openspot checks two of them, so you know your words bring your key back.")
            if let failure {
                fact(failure, "exclamationmark.triangle", .red)
            }
            ForEach(Array(zip(check, choices)), id: \.0) { place, offered in
                VStack(alignment: .leading, spacing: 6) {
                    Text("Word \(place)").fontWeight(.semibold)
                    HStack(spacing: 8) {
                        ForEach(offered, id: \.self) { word in
                            Button(word) { pick(word, at: place) }
                                .buttonStyle(.bordered)
                                .tint(picks[place] == word ? .accentColor : nil)
                        }
                    }
                }
            }
            HStack(spacing: 10) {
                Button("Show the Words Again") { step = .words }
                Spacer()
                Button("Later") { step = nil }
                    .keyboardShortcut(.cancelAction)
            }
            .controlSize(.large)
            .padding(.top, 6)
        }
    }

    private func pick(_ word: String, at place: Int) {
        picks[place] = word
        failure = nil
        guard check.allSatisfy({ picks[$0] != nil }) else { return }
        let places = check, picked = check.compactMap { picks[$0] }
        guard let secrets = spot.secrets else { return failure = SpotSecrets.missing }
        Task {
            if let failure = await secrets.confirm(places, picked) {
                self.failure = failure
                picks = [:]
            } else {
                step = nil
                send("say", "Your words are backed up")
            }
        }
    }

    private func leaveSheet(_ facts: [String: String]) -> some View {
        let place = facts["sync"] == "true" ? "all your Macs" : "this Mac"
        let isSaved = facts["backedUp"] == "true"
        return Group {
            sheetTitle("Sign out of your account?", "It leaves \(place)." + (isSaved ? " Your 12 words sign you in again." : ""))
            if !isSaved {
                HStack {
                    fact("You haven't saved its words", "exclamationmark.triangle", .red)
                    Spacer()
                    Button("Show My Words…") { step = .words }
                }
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { step = nil }
                    .keyboardShortcut(.cancelAction)
                Button("Sign Out", role: .destructive) {
                    step = nil
                    send("sign-out")
                }
                .keyboardShortcut(.defaultAction)
            }
            .controlSize(.large)
            .padding(.top, 6)
        }
    }

    /// Drops every word and phrase the steps held, once their sheet closes.
    private func forgetWords() {
        words = []
        phrase = ""
        picks = [:]
        failure = nil
    }

    private func rowsPage(_ title: String, _ line: String, section: String) -> some View {
        let rows = book.rows.filter { $0.spot == "openspot" && $0.section == section }
        return Group {
            heading(title, line)
            group(nil) {
                lines(rows) { settingLine($0) }
            }
        }
    }

    // MARK: Search

    private var results: some View {
        let fold = { (text: String) in text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        let folded = fold(query.trimmingCharacters(in: .whitespaces))
        let accesses = book.accesses.filter { fold($0.title).contains(folded) }
        let entries = book.entries.filter { $0.words.contains(folded) }
        let rows = book.rows.filter { $0.words.contains(folded) }
        let isEmpty = accesses.isEmpty && entries.isEmpty && rows.isEmpty
        return Group {
            heading("Results for “\(query)”", isEmpty ? "No row matches. Check the spelling, or try other words." : "Every row of every section that matches.")
            if !accesses.isEmpty {
                group("Access") {
                    lines(accesses) { access in
                        row(open: .accessOf(access.id)) {
                            tile(access.symbol, access.color, size: 24)
                            Text(access.title)
                            Spacer(minLength: 8)
                            Text(access.word).foregroundStyle(access.wordColor)
                            chevron
                        }
                    }
                }
            }
            if !entries.isEmpty {
                group("Spots") {
                    lines(entries) { spotLine($0, detail: $0.detail) }
                }
            }
            if !rows.isEmpty {
                group("Settings") {
                    lines(rows) { found in
                        row(action: { reveal(found) }) {
                            Text("\(found.name) · \(found.title)")
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            if found.form == "key" {
                                keycaps(found).allowsHitTesting(false)
                            } else if found.form != "secret" {
                                Text(display(found)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            chevron
                        }
                    }
                }
            }
        }
    }

    /// Opens the page that holds a row of the search, scrolled to the row.
    private func reveal(_ row: Row) {
        if row.spot == "openspot" {
            land("\(row.section)/\(row.id)")
        } else if book.entry(row.spot) == nil {
            land("keys/\(row.id)")
        } else {
            land("spot/\(row.spot)/\(row.key)")
        }
    }

    // MARK: Rows

    /// One row of `setting list`, drawn as System Settings draws it: a key as keycaps, a switch, or a field.
    private func settingLine(_ row: Row) -> some View {
        HStack(spacing: 12) {
            titled(row.title, row.detail)
            Spacer(minLength: 12)
            switch row.form {
            case "key":
                keycaps(row)
            case "toggle":
                Toggle("", isOn: Binding(get: { (pending[row.id] ?? row.value) == "true" }, set: { set(row, $0 ? "true" : "false") }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .controlSize(.small)
            case "field", "text":
                TextField("Not set", text: draft(row))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onSubmit { set(row, drafts[row.id] ?? row.value) }
            case "choice" where !row.options.isEmpty:
                Picker("", selection: Binding(get: { shown(row) }, set: { set(row, $0) })) {
                    if shown(row).isEmpty { Text("Not set").tag("") }
                    ForEach(row.options, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize()
            case "secret":
                SecureField((pending[row.id] ?? row.value).isEmpty ? "Not set" : "Set", text: draft(row, blank: true))
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onSubmit { keep(row) }
                    .onKeyPress(.delete) {
                        guard (drafts[row.id] ?? "").isEmpty, !(pending[row.id] ?? row.value).isEmpty else { return .ignored }
                        pending[row.id] = ""
                        send("remove", row.spot, row.key)
                        return .handled
                    }
            default:
                Text(display(row)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 40)
        .background(target == row.id ? Color.accentColor.opacity(0.15) : .clear)
        .id(row.id)
    }

    /// The value of a row, or its default while it has none.
    private func shown(_ row: Row) -> String {
        let value = pending[row.id] ?? row.value
        return value.isEmpty ? row.fallback : value
    }

    private func display(_ row: Row) -> String {
        switch (row.form, shown(row)) {
        case (_, ""): "Not set"
        case ("toggle", "true"): "On"
        case ("toggle", _): "Off"
        default: row.value
        }
    }

    private func draft(_ row: Row, blank: Bool = false) -> Binding<String> {
        Binding(get: { drafts[row.id] ?? (blank ? "" : row.value) }, set: { drafts[row.id] = $0 })
    }

    /// A row of a spot with its icon, name, a grey line and its state, which a click opens to its page.
    private func spotLine(_ entry: Entry, detail: String? = nil) -> some View {
        row(open: .spotOf(entry.id)) {
            spotIcon(entry, size: 28)
            titled(entry.title, detail ?? (entry.lacks ? lack(of: entry) : ""))
            Spacer(minLength: 8)
            if entry.lacks {
                Circle().fill(Color.orange).frame(width: 7, height: 7)
            }
            Text(entry.word).foregroundStyle(entry.lacks ? Color.primary : Color.secondary)
            chevron
        }
    }

    /// The grey line of what a spot lacks.
    private func lack(of entry: Entry) -> String {
        if entry.state == "review" {
            return entry.refused.isEmpty ? "Made a call it doesn’t declare" : "Tried \(entry.refused.joined(separator: ", ")), which it doesn’t declare"
        }
        return "Needs \(names(entry.needs))"
    }

    /// The step that lets a spot run: Allow… for the macOS access it lacks, or Review… for a use it doesn't declare.
    @ViewBuilder
    private func fix(_ entry: Entry) -> some View {
        if entry.state == "review" {
            Button("Review…") { send("review", entry.id, entry.refused.first ?? "") }
        } else {
            Button("Allow…") { send("allow", entry.id) }
        }
    }

    private func names(_ accesses: [String]) -> String {
        let titles = accesses.map { book.access($0)?.title ?? $0 }
        guard titles.count > 1 else { return titles.first ?? "" }
        return titles.dropLast().joined(separator: ", ") + " and " + titles[titles.count - 1]
    }

    private func purpose(of use: String) -> String {
        switch use {
        case "app": "Changes Openspot"
        case "spots": "Reads and changes your spots"
        case "screen": "Sees and moves what is on the screen"
        case "clipboard": "Reads and writes the clipboard"
        case "calendar": "Reads your calendars and reminders"
        case "power": "Keeps the Mac awake"
        case "network": "Reaches the internet"
        case "files": "Reads and writes files"
        case "timer": "Runs at a time"
        case "attachment": "Takes what you hand on"
        case "read": "Reads what you work on"
        case "account": "Signs what you publish"
        default: ""
        }
    }

    // MARK: Parts

    private func header<Trailing: View>(_ icon: some View, _ title: String, _ text: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(alignment: .top, spacing: 14) {
            icon
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                trailing()
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
    }

    private func heading(_ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
            Text(line)
                .foregroundStyle(.secondary)
        }
    }

    /// A group of rows on one rounded fill, under its title, as System Settings groups them.
    private func group<Rows: View>(_ title: String?, @ViewBuilder _ rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .fontWeight(.semibold)
            }
            VStack(spacing: 0) {
                rows()
            }
            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }

    /// Each item as a row, with a line between two rows, and above the first one too when it follows other rows.
    private func lines<Item: Identifiable, Line: View>(_ items: [Item], first: Bool = false, @ViewBuilder _ line: @escaping (Item) -> Line) -> some View {
        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
            if index > 0 || first {
                Divider().padding(.leading, 12)
            }
            line(item)
        }
    }

    private func row<Content: View>(open page: Page, @ViewBuilder _ content: () -> Content) -> some View {
        row(action: { go(page) }, content)
    }

    private func row<Content: View>(action: @escaping () -> Void, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            content()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityAddTraits(.isButton)
    }

    private func plain(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
    }

    private func titled(_ title: String, _ line: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .lineLimit(1)
            if !line.isEmpty {
                Text(line)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.tertiary)
    }

    /// The system's look of a macOS access: its symbol in white on a rounded tile of its colour.
    private func tile(_ symbol: String, _ color: Color, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(Image(systemName: symbol).font(.system(size: size * 0.52, weight: .medium)).foregroundStyle(.white))
    }

    /// The icon of a spot: its picture, or its symbol or emoji on a quiet tile.
    private func spotIcon(_ entry: Entry, size: CGFloat) -> some View {
        ZStack {
            if let image = book.images[entry.id] {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                if book.symbols.contains(entry.id) {
                    Image(systemName: entry.icon)
                        .font(.system(size: size * 0.5))
                } else {
                    Text(entry.icon.count == 1 ? entry.icon : String(entry.title.prefix(1)))
                        .font(.system(size: size * 0.55))
                }
            }
        }
        .frame(width: size, height: size)
    }

    // MARK: Steps

    private func title(of page: Page) -> String {
        switch page {
        case .accessOf(let id): book.access(id)?.title ?? id
        case .spotOf(let id): book.entry(id)?.title ?? id
        default: page.section.rawValue
        }
    }

    private func open(_ section: Section) {
        go(section.page)
    }

    private func go(_ next: Page) {
        guard next != page || !query.isEmpty else { return }
        if query.isEmpty { back.append(page) }
        forward = []
        query = ""
        recording = nil
        target = nil
        page = next
    }

    private func goBack() {
        guard let last = back.popLast() else { return }
        forward.append(page)
        recording = nil
        target = nil
        page = last
    }

    private func goForward() {
        guard let next = forward.popLast() else { return }
        back.append(page)
        recording = nil
        target = nil
        page = next
    }

    /// Lands on the page that `at` names: a section such as `keys`, `access/<id>`, `spot/<id>`, `spot/<id>/<key>` at one
    /// row, `<section>/<spot>/<key>` at one row of a section, `row/<spot>/<key>` on the page of a row, or `search/<words>`
    /// on the results of a search. A spot of the app itself has no page, so it lands on its keys.
    private func land(_ at: String) {
        let parts = at.split(separator: "/", maxSplits: 1).map(String.init)
        let rest = parts.count > 1 ? parts[1] : nil
        query = ""
        recording = nil
        back = []
        target = nil
        switch parts.first {
        case "access":
            page = rest.map { .accessOf($0) } ?? .access
        case "row":
            if let row = book.rows.first(where: { $0.id == rest }) { return reveal(row) }
            page = .access
        case "spot" where rest.map { id in book.entry(id) == nil && book.rows.contains { $0.spot == id } } == true:
            page = .keys
            target = rest.map { "\($0)/open" }
        case "spot", "spots":
            let words = rest?.split(separator: "/", maxSplits: 1).map(String.init) ?? []
            page = words.first.map { .spotOf($0) } ?? .spots
            if words.count > 1 { target = "\(words[0])/\(words[1])" }
        case "keys": page = .keys
        case "look": page = .look
        case "account": page = .account
        case "general": page = .general
        case "developer": page = .developer
        case "search": query = rest ?? ""
        default: page = .access
        }
        if target == nil, page.section != .spots, page.section != .access, rest?.contains("/") == true { target = rest }
    }

    /// Keeps the typed secret of a row through Openspot itself, so it never passes through a script.
    private func keep(_ row: Row) {
        guard let value = drafts[row.id], !value.isEmpty else { return }
        drafts[row.id] = nil
        guard let secrets = spot.secrets else { return send("say", SpotSecrets.missing) }
        Task {
            if let failure = await secrets.keep(value, key: row.key, of: row.spot) {
                send("say", failure)
            } else {
                pending[row.id] = "set"
            }
        }
    }

    private func set(_ row: Row, _ value: String) {
        pending[row.id] = value
        drafts[row.id] = nil
        send("set", row.spot, row.key, value)
    }

    private func send(_ words: String...) {
        spot.send(words.joined(separator: "\t"))
    }
}
