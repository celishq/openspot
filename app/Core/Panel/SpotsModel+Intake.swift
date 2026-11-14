import Foundation
import Observation

extension SpotsModel {
    public func acceptsDrop(_ paths: [String], on id: String, in place: SheetPlace = .panel) -> Bool {
        let isOpenToDrops = place == .panel ? openList == nil : runs.floating.contains(id)
        return isOpenToDrops && !SpotPackage.isFile(paths) && sheets[id]?.spot.accepts(paths) == true
    }

    public func card(at point: CGPoint) -> String? {
        placements.first { $0.rect.contains(point) }.map { visible[$0.index].id }
    }

    public func takesDrag(_ id: String) -> Bool {
        openList == nil && runs.takesDrag(id)
    }

    public func followDrag() {
        let paths = host.draggedPaths
        guard paths != dragPaths else { return }
        dragPaths = paths
        runs.draggedPaths = SpotPackage.isFile(paths) ? [] : paths
        isPointerOverDrop = host.isPointerOverDrop
        draggedSpot = SpotPackage.isFile(paths) ? SpotDrop(paths: paths, folder: folder.url) : nil
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
        draggedSpot = nil
        runs.draggedPaths = []
    }

    public func drop(_ paths: [String], on id: String, in place: SheetPlace = .panel) -> Bool {
        guard acceptsDrop(paths, on: id, in: place), sheets[id]?.drop(paths) == true else { return false }
        guard place == .panel else { return true }
        endDrag()
        guard entries.first(where: { $0.id == id })?.kind == .list else {
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
        guard openList != nil else { return }
        closeList(moving: false)
    }

    public func review(_ urls: [URL]) {
        guard let url = urls.first else { return }
        dragWatch?.cancel()
        endDrag()
        finishPick()
        closeMenu()
        form = nil
        closeList(moving: isShown)
        endReview()
        do {
            show(try ReviewSpot(file: url, folder: folder.url, lock: SpotLock.standard(environment: files.environment, home: files.home)))
            if urls.count > 1 { host.notify("Openspot installs one spot at a time.") }
        } catch {
            host.notify(Self.reason(error))
        }
    }

    @discardableResult
    public func reviewCore(_ id: String) -> Bool {
        let folder = self.folder
        do {
            let place = SpotsFolder(url: folder.url, core: folder.core, enabled: folder.enabled.union([id]), disabled: folder.disabled)
            let scan = try place.scan()
            guard let command = scan.spots.first(where: { place.isCore($0) && SpotsFolder.coreID(of: $0) == id }) else { return false }
            closeList(moving: isShown)
            show(try ReviewSpot(spot: SpotPackage(sharing: command, from: scan), folder: folder.url, canAdd: false))
        } catch {
            host.notify(Self.reason(error))
        }
        return true
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
        reload()
    }

    public func share(_ entry: Entry) {
        if isShown { host.dismiss() }
        Task {
            do {
                guard let spot = try await release(SpotPackage(sharing: entry.spot, from: folder.scan()), named: entry.spot.name) else { return }
                let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared/\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
                let file = place.appendingPathComponent(SpotPackage.fileName(for: entry.spot.name))
                try spot.zip(to: file)
                host.copy(file)
                host.confirm(spot.notice(name: entry.spot.name))
            } catch {
                host.notify("\(entry.spot.name) was not copied. \(Self.reason(error))")
            }
        }
    }
}
