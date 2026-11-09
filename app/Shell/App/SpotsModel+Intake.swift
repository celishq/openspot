import AppKit
import OpenspotCore
import SwiftUI

/// The drag of files over the panel, the review of a `.spot` file, and the share, removal and turn-off of a spot.
extension SpotsModel {
    /// Whether a card takes these dragged files. A card under an open sheet takes none.
    func acceptsDrop(_ paths: [String], on id: String) -> Bool {
        openList == nil && !SharedSpot.isFile(paths) && sheets[id]?.command.accepts(paths) == true
    }

    /// Whether a card shows that it takes the drag in progress.
    func takesDrag(_ id: String) -> Bool {
        openList == nil && runs.takesDrag(id)
    }

    /// Takes the files of a drag that reached the menu bar item or a card. When no mouse button is down, the cards stop
    /// showing them, and a panel that the drag opened closes.
    func followDrag() {
        let paths = SpotCardDrop.paths
        guard paths != dragPaths else { return }
        dragPaths = paths
        runs.draggedPaths = SharedSpot.isFile(paths) ? [] : paths
        isPointerOverDrop = pointerIsOverDrop()
        draggedSpot = SharedSpot.isFile(paths) ? SpotDrop(paths: paths, folder: PluginFolder.standard().url) : nil
        dragWatch?.cancel()
        dragWatch = Task { [weak self] in
            while NSEvent.pressedMouseButtons != 0 {
                try? await Task.sleep(for: Self.dragWatchPause)
                if Task.isCancelled { return }
                if let self { isPointerOverDrop = pointerIsOverDrop() }
            }
            try? await Task.sleep(for: Self.dropPause)
            guard !Task.isCancelled, let self else { return }
            endDrag()
            if isOpenForDrag, isShown { dismiss() }
        }
    }

    /// What the panel says while a `.spot` file is dragged over it or over the menu bar item.
    var spotDrop: SpotDrop? {
        isPointerOverDrop ? draggedSpot : nil
    }

    private func endDrag() {
        dragPaths = []
        draggedSpot = nil
        runs.draggedPaths = []
    }

    /// Takes a drop on a card and closes the panel. Returns false when the card does not take these files.
    func drop(_ paths: [String], on id: String) -> Bool {
        guard openList == nil, sheets[id]?.drop(paths) == true else { return false }
        endDrag()
        if isShown { dismiss() }
        return true
    }

    /// Shows the grid and not a sheet, so that a drag can reach the cards.
    func prepareForDrag() {
        isOpenForDrag = true
        followDrag()
        guard openList != nil else { return }
        sheetMoves = false
        closeList()
    }

    /// Opens the sheet that shows a `.spot` file before a person installs it. One file shows at a time, and a file it cannot read
    /// only says why.
    func review(_ urls: [URL]) {
        guard let url = urls.first else { return }
        dragWatch?.cancel()
        endDrag()
        finishPick()
        closeMenu()
        form = nil
        closeList()
        endReview()
        do {
            show(try ReviewSpot(spot: SharedSpot(contentsOf: url), folder: PluginFolder.standard().url))
            if urls.count > 1 { notify("Openspot installs one spot at a time.") }
        } catch {
            notify(Self.reason(error))
        }
    }

    /// Shows the text of a core spot, which is on or off, with no way to add it.
    func reviewCore(_ item: SpotItem) {
        let folder = PluginFolder.standard()
        do {
            let place = PluginFolder(url: folder.url, core: folder.core, enabled: folder.enabled.union([item.run]))
            let scan = try place.scan()
            guard let command = scan.commands.first(where: { place.isCore($0) && PluginFolder.coreID(of: $0) == item.run }) else { return }
            closeList()
            show(try ReviewSpot(spot: SharedSpot(sharing: command, from: scan), folder: folder.url, canAdd: false))
        } catch {
            notify(Self.reason(error))
        }
    }

    private func show(_ review: ReviewSpot) {
        let moves = isShown
        reviewed = review
        present()
        sheetMoves = moves
        open(ShippedSpot.command(reviewing: review).id)
    }

    /// What the search field says as the open review grows out of it.
    var reviewDrop: SpotDrop? {
        reviewed.map(SpotDrop.init(reviewing:))
    }

    /// Whether the panel stays open when it loses the focus: for a review, and for a first launch, because the Mac can keep
    /// another app in front of an app that just started.
    var holdsFocus: Bool {
        isReviewing || isFirstLaunch
    }

    /// Whether a review shows, which stays open when the panel loses the focus.
    var isReviewing: Bool {
        reviewed != nil
    }

    /// Opens the review of a `.spot` file on the clipboard. Returns false when the clipboard holds other things, or a form is open.
    func pasteSpot(from pasteboard: NSPasteboard = .general) -> Bool {
        let paths = SpotCardDrop.paths(on: pasteboard)
        guard form == nil, SharedSpot.isFile(paths) else { return false }
        review(paths.map { URL(fileURLWithPath: $0) })
        return true
    }

    /// Ends the review when its sheet has gone. Its sheet leaves with the next scan.
    func endReview() {
        guard reviewed != nil else { return }
        reviewed = nil
        reload()
    }

    /// Puts the file of a spot on the clipboard, ready to paste into a chat, and warns the sender about secrets.
    func share(_ entry: Entry) {
        if isShown { dismiss() }
        Task {
            do {
                let folder = PluginFolder.standard()
                var spot = try SharedSpot(sharing: entry.command, from: folder.scan())
                if spot.needsCompile {
                    confirm("Compiling \(entry.command.name)")
                    spot = try await spot.compiled()
                }
                let place = FileManager.default.temporaryDirectory.appendingPathComponent("openspot-shared/\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: place, withIntermediateDirectories: true)
                let file = place.appendingPathComponent(SharedSpot.fileName(for: entry.command.name))
                try spot.data.write(to: file)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([file as NSURL])
                confirm(spot.notice(name: entry.command.name))
            } catch {
                notify("\(entry.command.name) was not copied. \(Self.reason(error))")
            }
        }
    }

    /// Moves the file of a spot to the Trash. What it keeps in `$OPENSPOT_DATA` stays.
    func remove(_ entry: Entry) {
        closeList()
        if isShown { dismiss() }
        do {
            try PluginFolder.standard().remove(entry.command)
            confirm("\(entry.command.name) moved to the Trash")
            reload()
        } catch {
            notify("\(entry.command.name) was not removed. \(Self.reason(error))")
        }
    }

    /// Turns a core spot off. Its data stays, and it can come back from the Spots list.
    func turnOff(_ entry: Entry) {
        closeList()
        if isShown { dismiss() }
        do {
            try ConfigFile.standard().turn(PluginFolder.coreID(of: entry.command), on: false)
            confirm("\(entry.command.name) is off")
            reload()
        } catch {
            notify("\(entry.command.name) was not turned off. \(Self.reason(error))")
        }
    }
}
