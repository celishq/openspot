import Foundation
import os

extension SpotRun {
    static let appLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "openspot", category: "spots")

    func track(_ call: ScriptCall) {
        calls.append(call)
        guard call.doesWork else { return }
        workCalls.append(call)
        Task { [weak self, sleep = runs.clock.sleep] in
            var left = Self.workPause
            while left > 0 {
                try? await sleep(.seconds(left), .seconds(left / 10))
                guard !Task.isCancelled, let self, workCalls.contains(where: { $0 === call }) else { return }
                left = Self.workPause - runs.now().timeIntervalSince(call.started)
            }
            self?.showWork()
        }
    }

    func showWork() {
        let time = runs.now()
        let shown = workCalls.filter { time.timeIntervalSince($0.started) >= Self.workPause }
        guard !shown.elementsEqual(work, by: ===) else { return }
        work = shown
        runs.showWork()
    }

    func callEnded(_ call: ScriptCall) {
        forget(call)
        startWaitingFiles()
        startWaitingKey()
    }

    func drewFrame(_ call: ScriptCall) {
        guard let index = workCalls.firstIndex(where: { $0 === call }) else { return }
        workCalls.remove(at: index)
        showWork()
    }

    func forget(_ call: ScriptCall) {
        calls.removeAll { $0 === call }
        drewFrame(call)
    }

    func take(_ error: Error, of ask: Ask) {
        switch ask {
        case .read(_, let reports, _, let tells):
            answered = nil
            list.loadFailed()
            changeReading { $0.markStale() }
            answerArrived()
            if reports { fail(error, tells: tells) }
        case .answer(let query):
            takeAnswers([], to: query)
        case .search(let query):
            list.stopWaiting(for: query)
            answerArrived()
            if error as? SpotError != .timedOut { fail(error) }
        }
    }

    func lost() {
        scriptEnded()
        changeReading { $0.markStale() }
        dropUnshownSheet()
    }

    func scriptEnded() {
        answered = nil
        list.stopLoading()
    }

    static func search(of lines: SpotOutput, in spot: Spot) -> ItemSearch {
        lines.hidesSearch ? .off : spot.read?.searchesSheet == true ? .script : .local
    }

    func takeAnswer(_ lines: SpotOutput, frame: String, to ask: Ask, keeping: String? = nil, answers: Bool = true) async {
        if case .answer(let query) = ask { return takeAnswers(lines.answers, to: query) }
        if case .read = ask, !frame.isEmpty, frame == shownFrame, lines.parts.isEmpty, panel == nil, !list.hasFailed { return takeRepeat(lines, answers: answers) }
        let next: ItemList.Rows? = if case .read = ask { await newRows(lines.items, search: Self.search(of: lines, in: spot)) } else { nil }
        lastAnswer = lines
        shownFrame = if case .read = ask, !frame.isEmpty, frame.utf8.count <= Self.shownFrameLimit { frame } else { nil }
        report(toastOf: lines)
        spot = spot.taking(lines)
        switch ask {
        case .read(let generation, _, let query, _):
            if answers { answered = runs.now() }
            if spot.readsState { takeState(lines) }
            takeValue(lines)
            let kept = selecting
            selecting = nil
            let search = Self.search(of: lines, in: spot)
            let takeRows = {
                self.changeList {
                    $0.take(search: search)
                    $0.take(drawing: lines.drawing)
                    if let next { $0.replace(next) }
                    if let kept { $0.select(run: kept) }
                }
            }
            if showsSheet || panel != nil {
                takePanel(lines, generation: generation, keeping: keeping, rows: takeRows)
            } else {
                takeRows()
            }
            if list.search == .script, !list.query.isEmpty, list.query != query { self.ask() }
            takeSlash(lines)
        case .answer:
            return
        case .search(let query):
            await prepare(firstScreen(of: lines.items), [])
            guard query == list.query else { return }
            changeList {
                $0.take(search: Self.search(of: lines, in: spot))
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

    private static let shownFrameLimit = 256 * 1024

    private func takeRepeat(_ lines: SpotOutput, answers: Bool) {
        report(toastOf: lines)
        if answers { answered = runs.now() }
        takeValue(lines)
        let kept = selecting
        selecting = nil
        if list.isLoading || kept != nil {
            changeList {
                $0.stopLoading()
                if let kept { $0.select(run: kept) }
            }
        }
        if answers { answerArrived() }
        readAgainIfAsked()
    }

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

    private func takeSlash(_ lines: SpotOutput) {
        guard carriesSlash else { return }
        carriesSlash = false
        guard let id = lines.slash, let part = lines.parts.first(where: { $0.id == id && $0.isPressable }) else { return }
        onReport(.slash(part))
    }

    func takeMove(_ lines: SpotOutput) {
        if let move = lines.move { onReport(.move(move)) }
    }

    func takeEffects(_ lines: SpotOutput, frame: String) {
        report(toastOf: lines)
        onReport(.frame(frame))
    }

    var typedPart: String? {
        editing
    }

    private func newRows(_ items: [SpotItem], search: ItemSearch) async -> ItemList.Rows {
        let list = rows
        return await Task.detached(priority: .userInitiated) { list.ready(items, search: search) }.value
    }

    private func preparePictures() async {
        let rows = list.all
        if rows != glyphs.rows { glyphs = (rows, rows.compactMap(\.glyph)) }
        await prepare(firstScreen(of: list.shown), glyphs.glyphs)
    }

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

    func report(toastOf lines: SpotOutput) {
        if let text = lines.toast { onReport(.toast(fieldValues.hiding(text))) }
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

    private func takePanel(_ lines: SpotOutput, generation: Int?, keeping: String?, rows: () -> Void) {
        if lines.parts.isEmpty {
            rows()
            panel = nil
        } else if let current = panel?.generation {
            rows()
            panel?.take(lines, answering: generation ?? current, keeping: keeping)
            partsAnswers += 1
            onReport(.parts)
        } else {
            partsArrival {
                panel = SheetParts(output: lines)
                rows()
            }
            partsAnswers += 1
            onReport(.parts)
        }
    }

    func fail(_ error: Error, tells: Bool = true) {
        let said = switch error as? SpotError {
        case .failed(_, let message) where !message.isEmpty, .failedWithFix(_, let message, _) where !message.isEmpty: message
        case .timedOut: "\(spot.name) took too long, so Openspot stopped it."
        case .tooLarge: "\(spot.name) printed more than 32 MB in one frame, so Openspot stopped it."
        case let error?: "\(spot.name) failed. \(error.reason)"
        case nil: "\(spot.name) failed. \(error.localizedDescription)"
        }
        let text = fieldValues.hiding(said)
        failure = text
        runs.usage.failed(spot, fault: text, at: runs.now())
        guard tells else { return Self.appLog.info("\(text, privacy: .public)") }
        if case .failedWithFix(_, _, let fix) = error as? SpotError { return onReport(.failureWithFix(text, fix)) }
        onReport(.failure(text))
    }
}
