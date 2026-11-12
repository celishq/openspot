import Foundation

/// What the link of a run gives back: each call it starts and ends, and each frame of a call or of the script.
extension SpotRun {
    /// Lists a call that the link started, and shows it as running work once its second has passed.
    func track(_ call: ScriptCall) {
        calls.append(call)
        guard call.doesWork else { return }
        workCalls.append(call)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.workPause))
            self?.workPauses += 1
        }
    }

    /// Lets go of a call that ended, and starts a drop or a key press that waited for it.
    func callEnded(_ call: ScriptCall) {
        forget(call)
        startWaitingFiles()
        startWaitingKey()
    }

    /// Drops a call from the running calls. A call that is already gone tells no reader of the work.
    func forget(_ call: ScriptCall) {
        calls.removeAll { $0 === call }
        if let index = workCalls.firstIndex(where: { $0 === call }) { workCalls.remove(at: index) }
    }

    /// Takes the end of a call. A read or a search that ended with no answer changes nothing when it was stopped, and tells
    /// of its failure. A call of work that ended is followed by a read: with the row that a `select` effect named selected
    /// (D8), or else when it showed no picture (M4). A stopped toggle goes back.
    func ended(_ call: ScriptCall, _ purpose: Purpose, _ end: ScriptCall.End, hadAnswer: Bool, showedPicture: Bool, selected: String?) {
        let isAnswer = if case .ask(let ask) = purpose { ask.isAnswer } else { false }
        if case .ended = end, failure != nil, !isAnswer { failure = nil }
        switch (purpose, end) {
        case (.ask(.read), .stopped):
            list.stopLoading()
            if !hadAnswer {
                waiter = nil
                readsAgain = false
                eventAgain = nil
            }
        case (.ask(let ask), .failed(let error)):
            take(error, of: ask)
        case (.work(let work), .stopped):
            if let undo = work.undo { state = undo }
        case (.work(let work), .ended):
            answered = nil
            if let selected, spot.read != nil {
                read(selecting: selected, need: .change)
            } else if !showedPicture, work.readsAfter {
                readOnce()
            }
        case (.work(let work), .failed(let error)):
            answered = nil
            if let undo = work.undo { state = undo }
            fail(error)
            if work.readsAfter { readOnce() }
        default:
            break
        }
        callEnded(call)
        readAgainIfAsked()
    }

    /// Takes the failure of a read or a search, such as one that a staying script did not answer in time, and reads again
    /// when a change came meanwhile.
    func askFailed(_ ask: Ask, _ error: Error) {
        take(error, of: ask)
        readAgainIfAsked()
    }

    private func take(_ error: Error, of ask: Ask) {
        switch ask {
        case .read(_, let reports, _):
            answered = nil
            list.loadFailed()
            changeReading { $0.markStale() }
            answerArrived()
            if reports { fail(error) }
        case .answer(let query):
            takeAnswers([], to: query)
        case .search(let query):
            list.stopWaiting(for: query)
            answerArrived()
            if error as? SpotError != .timedOut { fail(error) }
        }
    }

    /// The script that held its own state ended by itself: its value dims, its answer is old, and a sheet that waited for it
    /// closes.
    func lost() {
        scriptEnded()
        changeReading { $0.markStale() }
        dropUnshownSheet()
    }

    /// Openspot ended the script that held its own state: its answer is old, so the next open waits for a new one.
    func scriptEnded() {
        answered = nil
        list.stopLoading()
    }

    /// Takes the answer of a read or of a search: a frame of it with a block, the head of one that ended with no picture, or
    /// the frame that ends a call of a staying script. A read's answer replaces all that the spot shows, and a search's
    /// answer replaces its rows (01, Y7). `keeping` names a part whose text the person owns while they type. A picture that
    /// answers no read, such as the frame of an action, leaves the age of the answer and a sheet that waits for a read. The
    /// rows that answer a text of the main search leave all else as it is (A2).
    func takeAnswer(_ lines: SpotOutput, frame: String, to ask: Ask, keeping: String? = nil, answers: Bool = true) async {
        if case .answer(let query) = ask { return takeAnswers(lines.answers, to: query) }
        let next: ItemList.Rows? = if case .read = ask { await newRows(lines.items, search: lines.search) } else { nil }
        lastAnswer = lines.withoutBlocks()
        report(toastOf: lines)
        spot = spot.taking(lines)
        switch ask {
        case .read(let generation, _, let query):
            if answers { answered = runs.now() }
            if spot.readsState { takeState(lines) }
            takeValue(lines)
            let kept = selecting
            selecting = nil
            changeList {
                $0.take(search: lines.search)
                $0.take(drawing: lines.drawing)
                if let next { $0.replace(next) }
                if let kept { $0.select(run: kept) }
            }
            if showsSheet || panel != nil { takePanel(lines, generation: generation, keeping: keeping) }
            if list.search == .script, !list.query.isEmpty, list.query != query { self.ask() }
        case .answer:
            return
        case .search(let query):
            await prepare(firstScreen(of: lines.items), [])
            guard query == list.query else { return }
            changeList {
                $0.take(search: lines.search)
                $0.take(drawing: lines.drawing)
                $0.answer(lines.items, to: query)
            }
        }
        if answers { answerArrived() }
        readAgainIfAsked()
        onReport(.frame(frame))
        guard case .read = ask else { return }
        await preparePictures()
        if !lines.errors.isEmpty {
            onReport(.failure("\(spot.name) sent \(lines.errors.count) items Openspot cannot read."))
        }
    }

    /// Takes a frame with a block of a call that is not a read or a search, or of a staying script by itself: the whole
    /// picture, unless a newer change has outdated its call (U10). Returns whether it showed. The state of a spot that reads
    /// no state of its own takes the value of its control from it.
    @discardableResult
    func takePicture(_ lines: SpotOutput, frame: String, of work: Work?) async -> Bool {
        if let generation = work?.generation, let current = panel?.generation, generation != current {
            takeEffects(lines, frame: frame)
            return false
        }
        await takeAnswer(lines, frame: frame, to: .read(generation: nil, reports: false, query: list.query), keeping: work?.keeping ?? editing, answers: false)
        if !spot.readsState { state = keepingLevel(state.taking(lines)) }
        return true
    }

    /// Takes a frame of only a head: its effects act, and the picture stays (01).
    func takeEffects(_ lines: SpotOutput, frame: String) {
        report(toastOf: lines)
        onReport(.frame(frame))
    }

    /// The part that the person is typing in, whose text a later frame of a read keeps.
    var typedPart: String? {
        editing
    }

    /// Fresh rows compared with the rows of the list and indexed off the main thread, so that the main thread takes them in
    /// one write.
    private func newRows(_ items: [SpotItem], search: ItemSearch) async -> ItemList.Rows {
        let list = rows
        return await Task.detached(priority: .userInitiated) { list.ready(items, search: search) }.value
    }

    /// Makes the pictures of the list ready: the first screen of its rows, and the colour glyphs of all of them, which it
    /// collects again only when the rows changed.
    private func preparePictures() async {
        let rows = list.all
        if rows != glyphs.rows { glyphs = (rows, rows.compactMap(\.glyph)) }
        await prepare(firstScreen(of: list.shown), glyphs.glyphs)
    }

    /// The first of these rows, as many as the sheet shows before it scrolls. A later row draws its picture when it shows.
    private func firstScreen(of items: [SpotItem]) -> [SpotItem] {
        Array(items.prefix(SpotTokens.firstScreen(perLine: list.perLine)))
    }

    func takeState(_ lines: SpotOutput?) {
        guard let lines, let next = try? spot.state(of: lines) else {
            if lines == nil { state = spot.headerState }
            return
        }
        state = keepingLevel(next)
    }

    /// The state with the level that the person set, while the call of that level waits or runs.
    private func keepingLevel(_ next: SpotState) -> SpotState {
        guard running(Self.levelKey) != nil || pauses[Self.levelKey] != nil, let level = state.level else { return next }
        return next.withLevel(level)
    }

    private func takeValue(_ lines: SpotOutput) {
        if let value = MetricValue(output: lines) {
            changeReading { $0.take(value) }
        } else {
            changeReading { $0.markStale() }
        }
    }

    /// Shows the toast of a frame.
    func report(toastOf lines: SpotOutput) {
        if let text = lines.toast { onReport(.toast(text)) }
    }

    private func changeReading(_ change: (inout MetricReading) -> Void) {
        var next = reading
        change(&next)
        reading = next
    }

    private func changeList(_ change: (inout ItemList) -> Void) {
        var next = rows
        change(&next)
        list = next
    }

    /// Shows the parts a script printed. An answer that a newer change outdated does not show.
    private func takePanel(_ lines: SpotOutput, generation: Int?, keeping: String?) {
        if lines.parts.isEmpty {
            panel = nil
        } else if let current = panel?.generation {
            panel?.take(lines, answering: generation ?? current, keeping: keeping)
        } else {
            partsArrival { panel = SheetParts(output: lines) }
        }
    }

    /// Tells the person about a failed call: the script's own message when it gave one, or else what Openspot saw.
    func fail(_ error: Error) {
        let text = switch error as? SpotError {
        case .failed(_, let message) where !message.isEmpty, .failedWithFix(_, let message, _) where !message.isEmpty: message
        case .timedOut: "\(spot.name) took too long, so Openspot stopped it."
        case let error?: "\(spot.name) failed. \(error.reason)"
        case nil: "\(spot.name) failed. \(error.localizedDescription)"
        }
        failure = text
        runs.usage.failed(spot, fault: text, at: runs.now())
        if case .failedWithFix(_, _, let fix) = error as? SpotError { return onReport(.failureWithFix(text, fix)) }
        onReport(.failure(text))
    }
}
