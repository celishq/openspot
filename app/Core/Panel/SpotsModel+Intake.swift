import Foundation
import Observation

/// The drag of files over the panel, the review of a `.spot` file, and the share, removal and turn-off of a spot.
extension SpotsModel {
    /// Whether a card takes these dragged files. A card under an open sheet takes none.
    public func acceptsDrop(_ paths: [String], on id: String) -> Bool {
        openList == nil && !SharedSpot.isFile(paths) && sheets[id]?.command.accepts(paths) == true
    }

    /// Whether a card shows that it takes the drag in progress.
    public func takesDrag(_ id: String) -> Bool {
        openList == nil && runs.takesDrag(id)
    }

    /// Takes the files of a drag that reached the menu bar item or a card. When no mouse button is down, the cards stop
    /// showing them, and a panel that the drag opened closes.
    public func followDrag() {
        let paths = host.draggedPaths
        guard paths != dragPaths else { return }
        dragPaths = paths
        runs.draggedPaths = SharedSpot.isFile(paths) ? [] : paths
        isPointerOverDrop = host.isPointerOverDrop
        draggedSpot = SharedSpot.isFile(paths) ? SpotDrop(paths: paths, folder: files.folder.url) : nil
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

    /// What the panel says while a `.spot` file is dragged over it or over the menu bar item.
    public var spotDrop: SpotDrop? {
        isPointerOverDrop ? draggedSpot : nil
    }

    private func endDrag() {
        dragPaths = []
        draggedSpot = nil
        runs.draggedPaths = []
    }

    /// Takes a drop on a card. A card with rows opens its sheet with the focus, so the person can act on what the drop added,
    /// and any other card closes the panel (D8). Returns false when the card does not take these files.
    public func drop(_ paths: [String], on id: String) -> Bool {
        guard openList == nil, sheets[id]?.drop(paths) == true else { return false }
        endDrag()
        guard entries.first(where: { $0.id == id })?.kind == .list else {
            if isShown { host.dismiss() }
            return true
        }
        let moves = isShown
        isSettlingDrop = true
        host.present()
        open(id, moving: moves)
        return true
    }

    /// Shows the grid and not a sheet, so that a drag can reach the cards.
    public func prepareForDrag() {
        isOpenForDrag = true
        followDrag()
        guard openList != nil else { return }
        closeList(moving: false)
    }

    /// Opens the sheet that shows a `.spot` file before a person installs it. One file shows at a time, and a file it cannot read
    /// only says why.
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
            show(try ReviewSpot(spot: SharedSpot(contentsOf: url), folder: files.folder.url))
            if urls.count > 1 { host.notify("Openspot installs one spot at a time.") }
        } catch {
            host.notify(Self.reason(error))
        }
    }

    /// Shows the text of a core spot, which is on or off, with no way to add it.
    public func reviewCore(_ item: SpotItem) {
        let folder = files.folder
        do {
            let place = PluginFolder(url: folder.url, core: folder.core, enabled: folder.enabled.union([item.run]))
            let scan = try place.scan()
            guard let command = scan.commands.first(where: { place.isCore($0) && PluginFolder.coreID(of: $0) == item.run }) else { return }
            closeList(moving: isShown)
            show(try ReviewSpot(spot: SharedSpot(sharing: command, from: scan), folder: folder.url, canAdd: false))
        } catch {
            host.notify(Self.reason(error))
        }
    }

    private func show(_ review: ReviewSpot) {
        let moves = isShown
        reviewed = review
        host.present()
        open(ShippedSpot.command(reviewing: review).id, moving: moves)
    }

    /// What the search field says as the open review grows out of it.
    public var reviewDrop: SpotDrop? {
        reviewed.map(SpotDrop.init(reviewing:))
    }

    /// Whether the panel stays open when it loses the focus: for a review, for a first launch, because the Mac can keep
    /// another app in front of an app that just started, and for a sheet that a drop just opened (D8).
    public var holdsFocus: Bool {
        isReviewing || isFirstLaunch || isSettlingDrop
    }

    /// Whether a review shows, which stays open when the panel loses the focus.
    public var isReviewing: Bool {
        reviewed != nil
    }

    /// Opens the review of a `.spot` file on the clipboard. Returns false when the clipboard holds other things, or a form is open.
    public func pasteSpot() -> Bool {
        let paths = host.pastedPaths
        guard form == nil, SharedSpot.isFile(paths) else { return false }
        review(paths.map { URL(fileURLWithPath: $0) })
        return true
    }

    /// Ends the review when its sheet has gone. Its sheet leaves with the next scan.
    public func endReview() {
        guard reviewed != nil else { return }
        reviewed = nil
        reload()
    }

    /// Puts the file of a spot on the clipboard, ready to paste into a chat, and warns the sender about secrets.
    public func share(_ entry: Entry) {
        if isShown { host.dismiss() }
        Task {
            do {
                let folder = files.folder
                var spot = try SharedSpot(sharing: entry.command, from: folder.scan())
                if spot.needsCompile {
                    host.confirm("Compiling \(entry.command.name)")
                    spot = try await spot.compiled()
                }
                let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared/\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
                let file = place.appendingPathComponent(SharedSpot.fileName(for: entry.command.name))
                try spot.data.write(to: file)
                host.copy(file)
                host.confirm(spot.notice(name: entry.command.name))
            } catch {
                host.notify("\(entry.command.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    /// Moves the file of a spot to the Trash. What it keeps in `$OPENSPOT_DATA` stays.
    public func remove(_ entry: Entry) {
        closeList(moving: isShown)
        if isShown { host.dismiss() }
        do {
            try files.folder.remove(entry.command)
            host.confirm("\(entry.command.name) moved to the Trash")
            reload()
        } catch {
            host.notify("\(entry.command.name) was not removed. \(Self.reason(error))")
        }
    }

    /// Turns a core spot off. Its data stays, and it can come back from the Spots list.
    public func turnOff(_ entry: Entry) {
        closeList(moving: isShown)
        if isShown { host.dismiss() }
        do {
            try files.config.turn(PluginFolder.coreID(of: entry.command), on: false)
            host.confirm("\(entry.command.name) is off")
            reload()
        } catch {
            host.notify("\(entry.command.name) was not turned off. \(Self.reason(error))")
        }
    }
}
