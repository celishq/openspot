import Foundation
import Observation

extension SpotsModel {
    public func acceptsDrop(_ paths: [String], on id: String, in place: SheetPlace = .panel) -> Bool {
        let isOpenToDrops = place == .panel ? openSheetID == nil : runs.floating.contains(id)
        guard isOpenToDrops, !SpotPackage.isFile(paths), let spot = sheets[id]?.spot else { return false }
        guard let files = dragged(paths) else { return spot.takesDrops }
        return spot.accepts(files)
    }

    private func dragged(_ paths: [String]) -> FileKinds? {
        if runs.dragged.paths == paths { return runs.dragged }
        if readPaths != paths { read(paths) }
        return nil
    }

    private func read(_ paths: [String]) {
        readPaths = paths
        dragRead?.cancel()
        if runs.dragged != FileKinds() { runs.dragged = FileKinds() }
        if draggedSpot != nil { draggedSpot = nil }
        guard !paths.isEmpty else { return }
        let kinds = files.kinds
        let folder = folder.url
        dragRead = Task { [weak self] in
            let (kinds, drop) = await Self.read(paths, kinds, folder)
            guard !Task.isCancelled, let self, readPaths == paths else { return }
            if let drop { draggedSpot = drop } else { runs.dragged = kinds }
        }
    }

    @concurrent
    private nonisolated static func read(_ paths: [String], _ kinds: @Sendable ([String]) -> FileKinds, _ folder: URL) async -> (FileKinds, SpotDrop?) {
        SpotPackage.isFile(paths) ? (FileKinds(), SpotDrop(paths: paths, folder: folder)) : (kinds(paths), nil)
    }

    public func card(at point: CGPoint) -> String? {
        placements.first { $0.rect.contains(point) }.map { visible[$0.index].id }
    }

    public func takesDrag(_ id: String) -> Bool {
        openSheetID == nil && runs.takesDrag(id)
    }

    public func followDrag() {
        let paths = host.draggedPaths
        guard paths != dragPaths else { return }
        dragPaths = paths
        read(paths)
        isPointerOverDrop = host.isPointerOverDrop
        dragWatch?.cancel()
        dragWatch = Task { [weak self] in
            while self?.host.isMouseDown == true {
                try? await Task.sleep(for: Self.dragWatchPause)
                if Task.isCancelled { return }
                if let self { isPointerOverDrop = host.isPointerOverDrop }
            }
            try? await Task.sleep(for: Self.dropPause)
            guard !Task.isCancelled, let self else { return }
            endDrag()
            if isOpenForDrag, isShown { host.dismiss() }
        }
    }

    public var spotDrop: SpotDrop? {
        isPointerOverDrop ? draggedSpot : nil
    }

    private func endDrag() {
        dragPaths = []
        read([])
    }

    public func drop(_ paths: [String], on id: String, in place: SheetPlace = .panel) -> Bool {
        guard acceptsDrop(paths, on: id, in: place), sheets[id]?.drop(paths, files: dragged(paths)) == true else { return false }
        guard place == .panel else { return true }
        endDrag()
        guard entry(id)?.kind == .list else {
            if isShown { host.dismiss() }
            return true
        }
        presentSheet(of: id, moving: isShown) {
            isSettlingDrop = true
            host.present()
        }
        return true
    }

    public func dragOut(_ items: [SpotItem], of id: String) {
        guard let sheet = sheets[id] else { return }
        sheet.dragged(items)
        let files = Set(sheet.list.shown.filter { $0.file != nil }.map(\.run))
        if runs.floating.contains(id), !files.isEmpty, files.isSubset(of: items.map(\.run)) { land(id) }
    }

    public func prepareForDrag() {
        isOpenForDrag = true
        followDrag()
        guard openSheetID != nil else { return }
        closeSheet(moving: false)
    }

    public func review(_ urls: [URL]) {
        guard let url = urls.first else { return }
        dragWatch?.cancel()
        endDrag()
        finishPick()
        closeMenu()
        form = nil
        closeSheet(moving: isShown)
        endReview()
        let folder = folder.url
        let lock = SpotLock.standard(environment: files.environment, home: files.home)
        reviewRead?.cancel()
        reviewRead = Task { [weak self] in
            let review = await Self.review(url, folder, lock)
            guard !Task.isCancelled, let self else { return }
            switch review {
            case .success(let review):
                show(review)
                if urls.count > 1 { host.notify("Openspot installs one spot at a time.") }
            case .failure(let error):
                host.notify(Self.reason(error))
            }
        }
    }

    @concurrent
    private nonisolated static func review(_ file: URL, _ folder: URL, _ lock: SpotLock) async -> Result<ReviewSpot, Error> {
        Result { try ReviewSpot(file: file, folder: folder, lock: lock) }
    }

    @discardableResult
    public func reviewCore(_ id: String) async -> Bool {
        do {
            guard let review = try await Self.review(core: id, in: folder).get() else { return false }
            closeSheet(moving: isShown)
            show(review)
        } catch {
            host.notify(Self.reason(error))
        }
        return true
    }

    @concurrent
    private nonisolated static func review(core id: String, in folder: SpotsFolder) async -> Result<ReviewSpot?, Error> {
        Result {
            let place = SpotsFolder(url: folder.url, core: folder.core, enabled: folder.enabled.union([id]), disabled: folder.disabled)
            let scan = try place.scan()
            guard let command = scan.spots.first(where: { place.isCore($0) && SpotsFolder.coreID(of: $0) == id }) else { return nil }
            return try ReviewSpot(spot: SpotPackage(sharing: command, from: scan), folder: folder.url, canAdd: false)
        }
    }

    private func show(_ review: ReviewSpot) {
        let moves = isShown
        reviewed = review
        host.present()
        pushFirst(review.spot.id, moving: moves)
    }

    public var reviewDrop: SpotDrop? {
        reviewed.map(SpotDrop.init(reviewing:))
    }

    public var holdsFocus: Bool {
        isReviewing || isFirstLaunch || isSettlingDrop || isAsking
    }

    public var isReviewing: Bool {
        reviewed != nil
    }

    public func pasteSpot() -> Bool {
        let paths = host.pastedPaths
        guard form == nil, SpotPackage.isFile(paths) else { return false }
        review(paths.map { URL(fileURLWithPath: $0) })
        return true
    }

    public func endReview() {
        guard reviewed != nil else { return }
        reviewed = nil
        Task { await reload() }
    }

    public func share(_ entry: Entry) {
        if isShown { host.dismiss() }
        let spot = entry.spot
        let folder = folder
        Task {
            do {
                let package = try await Self.package(sharing: spot, in: folder).get()
                guard let released = try await release(package, named: spot.name) else { return }
                let file = try await Self.zipped(released, named: spot.name).get()
                host.copy(file)
                host.confirm(released.notice(name: spot.name))
            } catch {
                host.notify("\(spot.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    @concurrent
    private nonisolated static func package(sharing spot: Spot, in folder: SpotsFolder) async -> Result<SpotPackage, Error> {
        Result { try SpotPackage(sharing: spot, from: folder.scan()) }
    }

    @concurrent
    private nonisolated static func zipped(_ package: SpotPackage, named name: String) async -> Result<URL, Error> {
        Result {
            let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared/\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
            let file = place.appendingPathComponent(SpotPackage.fileName(for: name))
            try package.zip(to: file)
            return file
        }
    }
}
