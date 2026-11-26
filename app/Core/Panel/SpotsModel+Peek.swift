import Foundation

extension SpotsModel {
    var peekRow: KeyRow {
        KeyRow("p", command: true, words: peekWords) { [self] _ in
            togglePeek() ? true : nil
        }
    }

    var peekEscapeRow: KeyRow {
        KeyRow("escape") { [self] _ in
            guard isPeeking else { return nil }
            closePeek()
            return true
        }
    }

    private var peekWords: String? {
        guard peekedItem != nil else { return nil }
        return isPeeking ? "Close Peek" : "Peek"
    }

    var peekedItem: SpotItem? {
        guard openSheetID != nil, let item = target?.item, Peek(item: item) != nil else { return nil }
        return item
    }

    @discardableResult
    func togglePeek() -> Bool {
        guard isPeeking || peekedItem != nil else { return false }
        asOnePress {
            isPeeking.toggle()
            takePeek()
        }
        return true
    }

    func closePeek() {
        guard isPeeking else { return }
        isPeeking = false
        takePeek()
    }

    func dropPeekNow() {
        isPeeking = false
        if peek != nil { peek = nil }
        dropPeek()
    }

    func takePeek() {
        if openSheetID == nil, isPeeking { isPeeking = false }
        let next = isPeeking ? peekedItem.flatMap(Peek.init(item:)) : nil
        if next != peek { peek = next }
        placePeek(beside: next == nil ? nil : openSheet?.sheetRect)
    }

    private func placePeek(beside sheet: CGRect?) {
        guard let sheet, isShown else {
            guard peekRect != nil else { return }
            guard isShown else { return dropPeek() }
            change(.sheet(isOpen: false), { isPeekOpen = false }, completion: { [weak self] in
                guard self?.isPeekOpen == false else { return }
                self?.dropPeek()
            })
            return
        }
        let width = SpotTokens.peekWidth
        let right = host.hasRoomRight(of: sheet, for: width + SpotTokens.peekGap)
        let rect = CGRect(x: right ? sheet.maxX + SpotTokens.peekGap : sheet.minX - SpotTokens.peekGap - width, y: sheet.minY, width: width, height: min(SpotTokens.peekHeight, sheet.height))
        guard rect != peekRect || !isPeekOpen && !isPeekGrowing else { return }
        let isNew = peekRect == nil
        if rect != peekRect {
            host.reach(rect)
            let side = 2 * SpotTokens.cardRadius
            let source = CGRect(x: right ? sheet.maxX - side : sheet.minX, y: rect.minY, width: side, height: rect.height)
            if source != peekSource { peekSource = source }
            peekRect = rect
        }
        if isNew {
            isPeekGrowing = true
            host.nextFrame { [weak self] in
                guard let self, isPeekGrowing else { return }
                isPeekGrowing = false
                guard peekRect != nil, isPeeking else { return }
                change(.sheet(isOpen: true)) { isPeekOpen = true }
            }
        } else if !isPeekOpen, !isPeekGrowing {
            change(.sheet(isOpen: true)) { isPeekOpen = true }
        }
    }

    private func dropPeek() {
        isPeekGrowing = false
        if isPeekOpen { isPeekOpen = false }
        if peekRect != nil { peekRect = nil }
        if peekSource != nil { peekSource = nil }
        host.reach(nil)
    }
}
