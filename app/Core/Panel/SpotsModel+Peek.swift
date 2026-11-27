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

    public var peekPlays: Bool {
        guard isShown, isPeekGrown, !isPeekPaused, case .video = peek?.look else { return false }
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
        placePeek(beside: next == nil ? nil : openSheet?.sheetRect)
        if let next, next != peek {
            peek = next
            if isPeekPaused { isPeekPaused = false }
        }
        readAhead(around: next == nil ? nil : peekedItem)
    }

    private func readAhead(around item: SpotItem?) {
        guard let item else {
            peekRead = []
            return
        }
        let rows = openSheet?.list.shown ?? []
        let at = rows.firstIndex { $0.run == item.run }
        let around = [item] + [at.map { $0 + 1 }, at.map { $0 - 1 }].compactMap { $0 }.filter(rows.indices.contains).map { rows[$0] }
        let looks = around.compactMap(Peek.init(item:)).filter(\.isRead).map(\.look)
        guard looks != peekRead else { return }
        peekRead = looks
        host.readAhead(looks)
    }

    private func placePeek(beside sheet: CGRect?) {
        guard let sheet, isShown else {
            guard peekRect != nil else { return }
            guard isShown else { return dropPeek() }
            guard isPeekOpen || isPeekGrowing else { return }
            isPeekGrowing = false
            change(.sheet(isOpen: false), {
                isPeekOpen = false
                if isPeekGrown { isPeekGrown = false }
            }, completion: { [weak self] in
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
                grow()
            }
        } else if !isPeekOpen, !isPeekGrowing {
            grow()
        }
    }

    private func grow() {
        change(.sheet(isOpen: true), { isPeekOpen = true }, completion: { [weak self] in
            guard let self, isPeekOpen, !isPeekGrown else { return }
            isPeekGrown = true
        })
    }

    private func dropPeek() {
        isPeekGrowing = false
        if peek != nil { peek = nil }
        if isPeekGrown { isPeekGrown = false }
        if isPeekOpen { isPeekOpen = false }
        if peekRect != nil { peekRect = nil }
        if peekSource != nil { peekSource = nil }
        host.reach(nil)
    }

    func perform(_ act: PeekAct, by spot: Spot) {
        if isShown { host.dismiss() }
        if let url = act.url { return host.open(url) }
        guard let api = runs.api else { return }
        let caller = SpotCaller(spot: spot)
        Task { [weak self] in
            for arguments in act.calls {
                let request = CommandRequest(arguments: arguments, folder: "/", caller: caller)
                guard let work = api.work(for: request, input: { act.input }) else { return }
                let answer = await work()
                guard answer.code == 0 else {
                    self?.toast(.failure(answer.errors.trimmingCharacters(in: .whitespacesAndNewlines)))
                    return
                }
            }
        }
    }
}
