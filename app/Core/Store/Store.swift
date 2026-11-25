import Foundation
import Observation

@MainActor
@Observable
public final class Store {
    public private(set) var sources: [StoreSource] = []
    public private(set) var missing: Set<String> = []
    public private(set) var place = StorePlace.mine
    public private(set) var query = ""
    public private(set) var cards: [StoreCard] = []
    public private(set) var page: StorePage?
    public private(set) var ask: StoreAsk?
    @ObservationIgnored private var shelves: [StorePlace: [StoreCard]] = [:]
    @ObservationIgnored private var opening: String?
    @ObservationIgnored private let places: AppPlaces
    @ObservationIgnored private let clock: RunClock
    @ObservationIgnored private let changed: @MainActor () async -> Void
    @ObservationIgnored private let toast: @MainActor (ToastNote) -> Void

    public init(
        places: AppPlaces, clock: RunClock = RunClock(), changed: @escaping @MainActor () async -> Void = {}, toast: @escaping @MainActor (ToastNote) -> Void = { _ in }
    ) {
        self.places = places
        self.clock = clock
        self.changed = changed
        self.toast = toast
    }

    public var placesInOrder: [StorePlace] {
        [.mine] + sources.map { .source($0.url) }
    }

    public func read() async {
        let shelf = await Self.read(places)
        if shelf.tookUpdates { await changed() }
        if sources != shelf.sources { sources = shelf.sources }
        if missing != shelf.missing { missing = shelf.missing }
        shelves = shelf.cards
        if shelves[place] == nil {
            place = .mine
            page = nil
        }
        refilter()
    }

    public func show(_ id: String?, search text: String?) async -> Bool {
        await read()
        if let text {
            query = text
            let folded = StoreCard.fold(text.trimmingCharacters(in: .whitespaces))
            let matched = (placesInOrder.dropFirst() + [.mine]).first { place in shelves[place]?.contains { $0.words.contains(folded) } == true }
            choose(matched ?? .mine)
            refilter()
        }
        guard let id else { return true }
        guard let found = placesInOrder.first(where: { place in shelves[place]?.contains { $0.id == id } == true }) else { return false }
        choose(found)
        await open(id)
        return page?.id == id
    }

    public func choose(_ next: StorePlace) {
        if page != nil { page = nil }
        guard next != place else { return }
        place = next
        refilter()
    }

    public func search(_ text: String) {
        guard text != query else { return }
        query = text
        if page != nil { page = nil }
        refilter()
    }

    public func open(_ id: String) async {
        opening = id
        let next = await Self.page(id, at: place, places, now: clock.now())
        guard opening == id else { return }
        opening = nil
        page = next
    }

    public func closePage() {
        opening = nil
        if page != nil { page = nil }
    }

    public func install(_ id: String) async {
        switch await Self.review(id, at: place, places, now: clock.now()) {
        case .success(let review?): ask = review.clashes ? .clash(review) : .install(review)
        case .success(nil): toast("\(id) is one of your spots already.")
        case .failure(let error): toast(.failure(SpotsModel.reason(error)))
        }
    }

    public func update(_ id: String) async {
        let update = SpotUpdate(places: places, clock: clock)
        switch await Self.run({ try StoreChange(id: id, name: update.name(of: id), powers: update.powers(id)) }) {
        case .success(let change): ask = .update(change)
        case .failure(let error): toast(.failure(SpotsModel.reason(error)))
        }
    }

    public func revert(_ id: String) async {
        let update = SpotUpdate(places: places, clock: clock)
        switch await Self.run({ try StoreChange(id: id, name: update.name(of: id), powers: update.powers(id)) }) {
        case .success(let change): ask = .revert(change)
        case .failure(let error): toast(.failure(SpotsModel.reason(error)))
        }
    }

    public func confirm(_ clash: SpotClash? = nil) async {
        guard let ask else { return }
        let update = SpotUpdate(places: places, clock: clock)
        switch ask {
        case .clash(let review):
            guard let clash else { return }
            self.ask = .install(review.choosing(clash))
        case .install(let review):
            self.ask = nil
            await act { try await review.install.run(review.clash, isConfirmed: true) }
        case .update(let change):
            self.ask = nil
            await act { try await update.run(change.id, isConfirmed: true) }
        case .revert(let change):
            self.ask = nil
            await act { try await update.revert(change.id, isConfirmed: true) }
        }
    }

    public func dismissAsk() {
        if ask != nil { ask = nil }
    }

    public func addSource(_ url: URL) async {
        let config = places.config
        await act { try StoreSource.add(url, to: config) }
        let added = StoreSource(url: url).url
        if sources.contains(where: { $0.url == added }) { choose(.source(added)) }
    }

    public func removeSource(_ url: URL) async {
        let config = places.config
        await act { try StoreSource.remove(url, from: config) }
    }

    private func act(_ work: @escaping @Sendable () async throws -> String) async {
        switch await Self.run(work) {
        case .success(let said):
            await changed()
            await read()
            if let id = page?.id { await open(id) }
            toast(ToastNote(words: said.trimmingCharacters(in: .newlines)))
        case .failure(let error):
            toast(.failure(SpotsModel.reason(error)))
        }
    }

    private func refilter() {
        let folded = StoreCard.fold(query.trimmingCharacters(in: .whitespaces))
        let next = (shelves[place] ?? []).filter { folded.isEmpty || $0.words.contains(folded) }
        if next != cards { cards = next }
    }

    @concurrent
    private nonisolated static func run<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }

    private nonisolated static func sources(in places: AppPlaces, config: Config) -> [StoreSource] {
        StoreSource.all(builtIn: places.examples, config: config).filter { !$0.isBuiltIn || $0.exists() }
    }

    private nonisolated static func catalog(_ places: AppPlaces, _ config: Config, sources: [StoreSource]) -> SpotCatalog {
        SpotCatalog(published: places.store, folder: places.spots, arrangement: config.arrangement, stores: sources, lock: places.lock)
    }

    @concurrent
    private nonisolated static func read(_ places: AppPlaces) async -> StoreShelf {
        let before = try? places.lock.entries()
        await SpotUpdate(places: places).takeEachWithNoNewPower()
        let tookUpdates = (try? places.lock.entries()) != before
        let config = places.config.read()
        let sources = sources(in: places, config: config)
        let mine = catalog(places, config, sources: []).items(publications: false).filter(\.isAdded).map { StoreCard(id: $0.id, spot: $0.spot, mark: StoreMark(of: $0)) }
        let had = Set(mine.map(\.id))
        var cards: [StorePlace: [StoreCard]] = [.mine: mine]
        for source in sources {
            cards[.source(source.url)] = source.spots().compactMap { file in
                file.spots.first.map { StoreCard(id: file.id, spot: $0, mark: had.contains(file.id) ? .installed : nil) }
            }.sorted { $0.spot.name.localizedCaseInsensitiveCompare($1.spot.name) == .orderedAscending }
        }
        return StoreShelf(sources: sources, missing: Set(sources.filter { !$0.exists() }.map(\.url.path)), cards: cards, tookUpdates: tookUpdates)
    }

    @concurrent
    private nonisolated static func page(_ id: String, at place: StorePlace, _ places: AppPlaces, now: Date) async -> StorePage? {
        let config = places.config.read()
        let folder = places.spots
        let own = catalog(places, config, sources: []).items(publications: false).first { $0.id == id && $0.isAdded }
        let button: StoreButton = own == nil ? .install : own?.origin == .core ? .locked : own?.copy == .update ? .update : own?.copy == .edited ? .edited : .installed
        switch place {
        case .mine:
            guard let own else { return nil }
            let review = (try? folder.scan()).flatMap { try? ReviewSpot(spot: SpotPackage(sharing: own.spot, from: $0), folder: folder.url, core: folder.core, canAdd: false) }
            let entry = own.origin == .core ? nil : (try? places.lock.entries())?.first { $0.holds(id) }
            let from = own.origin == .core ? "Comes with Openspot" : entry.map { "From \(name(ofSource: $0, in: places, config: config))" } ?? "Yours"
            let text = readme(beside: own.spot)
            return StorePage(
                id: id, spot: own.spot, from: from, updated: own.version.map { "Updated \($0.day(now: now))" }, readme: text.lines, shown: text.shown,
                trust: review?.lines ?? [], button: button, hasSample: SpotSample.exists(for: own.spot, runsScript: true), runsSample: true
            )
        case .source(let url):
            guard let source = StoreSource.all(builtIn: places.examples, config: config).first(where: { $0.url == url }),
                  let spot = source.spots().first(where: { $0.id == id })?.spots.first else { return nil }
            let spotFolder = spot.url.deletingLastPathComponent()
            let review = try? ReviewSpot(
                spot: SpotPackage(paths: [spotFolder.lastPathComponent], in: spotFolder.deletingLastPathComponent()), folder: folder.url, core: folder.core, canAdd: false
            )
            let text = readme(beside: spot)
            return StorePage(
                id: id, spot: spot, from: "From \(source.name)", updated: (try? SpotVersion(of: spotFolder)).map { "Updated \($0.day(now: now))" },
                readme: text.lines, shown: text.shown, trust: review?.lines ?? [], button: button == .locked ? .installed : button,
                hasSample: SpotSample.exists(for: spot, runsScript: false), runsSample: false
            )
        }
    }

    private nonisolated static func readme(beside spot: Spot) -> (lines: [String], shown: [StoreReadmeLine]) {
        let lines = SpotReadme.lines(at: SpotReadme.url(beside: spot.url))
        return (lines, lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map(StoreReadmeLine.init))
    }

    private nonisolated static func name(ofSource entry: SpotLock.Entry, in places: AppPlaces, config: Config) -> String {
        if places.lock.origin(of: entry).isBuiltIn, let builtIn = places.examples { return builtIn.name }
        let folder = URL(fileURLWithPath: entry.source).standardizedFileURL.deletingLastPathComponent()
        return StoreSource.all(builtIn: places.examples, config: config).first { $0.url.path == folder.path }?.name ?? folder.lastPathComponent
    }

    @concurrent
    private nonisolated static func review(_ id: String, at place: StorePlace, _ places: AppPlaces, now: Date) async -> Result<StoreReview?, Error> {
        Result {
            let config = places.config.read()
            let sources = sources(in: places, config: config)
            let chosen: StoreSource? = if case .source(let url) = place { sources.first { $0.url == url } } else { nil }
            guard let install = try catalog(places, config, sources: sources).install(id, in: places, from: chosen) else { return nil }
            let source = chosen ?? sources.first { $0.fetch(id) != nil }
            return StoreReview(
                name: install.name, from: "From \(source?.name ?? install.source.deletingLastPathComponent().lastPathComponent)",
                updated: (try? SpotVersion(of: install.source)).map { "Updated \($0.day(now: now))" }, lines: try install.review().lines, clash: nil, install: install,
                clashes: install.clashes()
            )
        }
    }
}
