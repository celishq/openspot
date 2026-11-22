import Foundation
import os

extension SpotRun {
    static let appLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "openspot", category: "spots")

    func track(_ call: ScriptCall) {
        calls.append(call)
        guard call.isAct else { return }
        actCalls.append(call)
        Task { [weak self, sleep = runs.clock.sleep] in
            var left = Self.actPause
            while left > 0 {
                try? await sleep(.seconds(left), .seconds(left / 10))
                guard !Task.isCancelled, let self, actCalls.contains(where: { $0 === call }) else { return }
                left = Self.actPause - runs.now().timeIntervalSince(call.started)
            }
            self?.showActs()
        }
    }

    func showActs() {
        let time = runs.now()
        let shown = actCalls.filter { time.timeIntervalSince($0.started) >= Self.actPause }
        guard !shown.elementsEqual(acts, by: ===) else { return }
        acts = shown
        runs.showActs()
    }

    func callEnded(_ call: ScriptCall) {
        forget(call)
        startWaitingFiles()
        startWaitingKey()
    }

    func drewFrame(_ call: ScriptCall) {
        guard let index = actCalls.firstIndex(where: { $0 === call }) else { return }
        actCalls.remove(at: index)
        showActs()
    }

    func forget(_ call: ScriptCall) {
        calls.removeAll { $0 === call }
        drewFrame(call)
    }

    func take(_ error: Error, of ask: Ask) {
        switch ask {
        case .show(_, let reports, _, let tells):
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

    static func search(of lines: Frame, in spot: Spot) -> ItemSearch {
        spot.on?.searchesSheet == true ? .script : lines.search
    }

    func takeAnswer(_ lines: Frame, frame: String, to ask: Ask, keeping: String? = nil, answers: Bool = true) async {
        if case .answer(let query) = ask { return takeAnswers(lines.answers(asCard: spot.answers?.isCard == true), to: query) }
        if case .show = ask, !frame.isEmpty, frame == shownFrame, lines.parts.isEmpty, panel?.holdsParts != true, !list.hasFailed { return takeRepeat(lines, answers: answers) }
        let next: ItemList.Rows? = if case .show = ask { await newRows(lines.items, search: Self.search(of: lines, in: spot)) } else { nil }
        lastAnswer = lines
        shownFrame = if case .show = ask, !frame.isEmpty, frame.utf8.count <= Self.shownFrameLimit { frame } else { nil }
        spot = spot.taking(lines)
        switch ask {
        case .show(let generation, _, let query, _):
            if answers { answered = runs.now() }
            if spot.showsState { takeState(lines) }
            takeValue(lines)
            let kept = selecting
            selecting = nil
            let search = Self.search(of: lines, in: spot)
            let takeRows = {
                self.changeList {
                    $0.take(search: search)
                    $0.take(perLine: lines.columns)
                    if let next { $0.replace(next) }
                    if let kept { $0.select(run: kept) }
                }
            }
            if showsSheet || panel?.holdsParts == true {
                takePanel(lines, generation: generation, keeping: keeping, rows: takeRows)
            } else {
                takeRows()
            }
            if list.search == .script, !list.query.isEmpty, list.query != query { self.ask() }
        case .answer:
            return
        case .search(let query):
            await prepare(firstScreen(of: lines.items), [])
            guard query == list.query else { return }
            changeList {
                $0.take(search: Self.search(of: lines, in: spot))
                $0.take(perLine: lines.columns)
                $0.answer(lines.items, to: query)
            }
        }
        if answers { answerArrived() }
        showAgainIfAsked()
        onReport(.frame(frame))
        guard case .show = ask else { return }
        await preparePictures()
        if !lines.errors.isEmpty {
            onReport(.failure("\(spot.name) sent \(lines.errors.count) items Openspot cannot read."))
        }
    }

    private static let shownFrameLimit = 256 * 1024

    private func takeRepeat(_ lines: Frame, answers: Bool) {
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
        showAgainIfAsked()
    }

    @discardableResult
    func takePicture(_ lines: Frame, frame: String, of act: Act?) async -> Bool {
        if let generation = act?.generation, let current = panel?.generation, generation != current {
            takeEffects(frame: frame)
            return false
        }
        await takeAnswer(lines, frame: frame, to: .show(generation: nil, reports: false, query: list.query), keeping: act?.keeping ?? editing, answers: false)
        if !spot.showsState { state = keepingLevel(state.taking(lines)) }
        return true
    }

    func takeEffects(frame: String) {
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

    func takeState(_ lines: Frame?) {
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

    private func takeValue(_ lines: Frame) {
        let value = MetricValue(output: lines.hasBar ? lines.barred : lines)
        changeReading {
            $0.hasBar = lines.hasBar
            if let value { $0.take(value) } else { $0.markStale() }
        }
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

    private func takePanel(_ lines: Frame, generation: Int?, keeping: String?, rows: () -> Void) {
        if lines.parts.isEmpty {
            rows()
            panel = SheetParts(output: lines, variants: runs.variants(of: spot.id))
        } else if let current = panel?.generation, panel?.holdsParts == true {
            rows()
            guard panel?.take(lines, answering: generation ?? current, keeping: keeping) == true else { return }
            partsAnswers += 1
            onReport(.parts)
        } else {
            partsArrival {
                panel = SheetParts(output: lines, variants: runs.variants(of: spot.id))
                rows()
            }
            partsAnswers += 1
            onReport(.parts)
        }
    }

    func fail(_ error: Error, tells: Bool = true, item: String? = nil) {
        let said = switch error as? SpotError {
        case .failed(_, let message) where !message.isEmpty, .failedWithFix(_, let message, _) where !message.isEmpty: message
        case .timedOut: "\(spot.name) took too long, so Openspot stopped it."
        case .tooLarge: "\(spot.name) printed more than 32 MB in one frame, so Openspot stopped it."
        case let error?: "\(spot.name) failed. \(error.reason)"
        case nil: "\(spot.name) failed. \(error.localizedDescription)"
        }
        let text = fieldValues.hiding(said)
        failure = text
        if failedItem != item { failedItem = item }
        runs.usage.failed(spot, fault: text, at: runs.now())
        guard tells else { return Self.appLog.info("\(text, privacy: .public)") }
        if case .failedWithFix(_, _, let fix) = error as? SpotError { return onReport(.failureWithFix(text, fix)) }
        onReport(.failure(text))
    }
}
