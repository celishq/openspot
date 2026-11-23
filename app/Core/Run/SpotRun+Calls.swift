import Foundation

extension SpotRun {
    @discardableResult
    func send(_ call: Call) -> Bool {
        var call = call
        if case .ask = call.purpose {} else {
            if let action = try? spot.action(call.handler) {
                do {
                    call.message.inputs = try action.check.checked(call.message.inputs, keepingUndeclared: true)
                } catch {
                    refuse(call, error)
                    return true
                }
            }
            acted()
        }
        return link.send(OpenCall(call, started: runs.now()))
    }

    private func refuse(_ call: Call, _ error: Error) {
        switch call.purpose {
        case .form(let waiting):
            waiting.resume(throwing: error)
        case .act(let act):
            act.first?.end(.stopped)
            fail(error)
            act.ended?()
        case .ask:
            break
        }
    }

    private func refusal(of lines: Frame, in call: OpenCall) -> SpotError? {
        if let message = lines.root?.value(RootKey.error) { return .failed(1, message) }
        let outputs = lines.outputs
        guard !outputs.isEmpty, let action = try? spot.action(call.request.handler), let fault = action.fault(in: outputs) else { return nil }
        return .fault(fault)
    }

    func acted() {
        guard OwnedSheet.owner(of: spot.id) == nil else { return }
        runs.usage.acted(spot, at: runs.now())
    }

    func answer(to message: Message, key: String, chain: [String] = [], isPressed: Bool = true) async throws -> Frame? {
        try await withCheckedThrowingContinuation { waiting in
            if !send(Call(message: message, key: key, purpose: .form(waiting), chain: chain, isPressed: isPressed)) { waiting.resume(returning: nil) }
        }
    }

    func take(_ text: String, _ lines: Frame, of call: OpenCall) async {
        if call.answered == nil { call.answered = Date().timeIntervalSince(call.begin) }
        if call.refusal == nil { call.refusal = refusal(of: lines, in: call) }
        if !lines.outputs.isEmpty || lines.root?.value(RootKey.error) != nil { runs.answerPushed(lines, from: spot.id) }
        call.made.take(lines)
        switch call.request.purpose {
        case .ask(let ask):
            if lines.isPicture {
                await takeAnswer(lines, frame: text, to: ask, keeping: call.hasAnswer ? typedPart : nil)
                call.hasAnswer = true
            } else {
                call.lastHead = lines
                takeEffects(frame: text)
            }
        case .act(let act):
            if act.first?.take(lines) == true, lines.isForm {
                call.showedPicture = true
                return
            }
            if lines.isPicture {
                if await takePicture(lines, frame: text, of: act) {
                    call.showedPicture = true
                    drewFrame(call.made)
                }
            } else {
                takeEffects(frame: text)
            }
        case .form:
            if lines.isForm || !call.form.isForm { call.form = lines }
        }
    }

    func take(_ text: String, _ lines: Frame) async {
        if lines.isPicture {
            await takePicture(lines, frame: text, of: nil)
        } else {
            takeEffects(frame: text)
        }
    }

    func take(answers text: String?, to query: String, of call: OpenCall, _ end: ScriptCall.End, errors: String) {
        takeAnswers(text.map { Frame(text: $0).answers(asCard: spot.triggers.search?.isCard == true) } ?? [], to: query)
        call.hasAnswer = text != nil
        finish(call, end, errors: errors)
    }

    func takeEnd(of call: OpenCall, _ end: ScriptCall.End) async {
        guard case .ended = end, !call.hasAnswer, case .ask(let ask) = call.request.purpose else { return }
        call.hasAnswer = true
        await takeAnswer((call.pushed ?? call.lastHead)?.withoutEffects() ?? .empty, frame: "", to: ask)
    }

    func finish(_ call: OpenCall, _ end: ScriptCall.End, errors: String = "") {
        var end = end
        if case .ended = end, let refusal = call.refusal { end = .failed(refusal) }
        if OwnedSheet.owner(of: spot.id) == nil {
            runs.usage.called(spot, call.outcome(end), at: runs.now())
        }
        log(call, end, errors: errors)
        ended(call, end)
        runs.settlePushed(of: spot.id)
    }

    func lose(_ call: OpenCall, _ end: ScriptCall.End, errors: String = "") {
        log(call, end, errors: errors)
        switch call.request.purpose {
        case .ask(.answer(let query)):
            takeAnswers([], to: query)
        case .ask:
            break
        case .act(let act):
            act.first?.end(.stopped)
            if let undo = act.undo { state = undo }
            callEnded(call.made)
        case .form(let waiting):
            callEnded(call.made)
            answer(waiting, of: call, end)
        }
    }

    private func log(_ call: OpenCall, _ end: ScriptCall.End, errors: String) {
        guard !script.answersInApp, runs.recordsCalls else { return }
        let request = call.request
        let values = fieldValues
        var sent = message(of: request, values: values)
        sent.settings = []
        runs.record(spot, sent.handler, input: values.hiding(sent.text), frames: call.frames.map(values.hiding), errors: values.hiding(errors), end: end, event: request.event, started: call.made.started, begin: call.begin)
    }

    private func answer(_ waiting: CheckedContinuation<Frame?, Error>, of call: OpenCall, _ end: ScriptCall.End) {
        switch end {
        case .stopped: waiting.resume(returning: nil)
        case .ended: waiting.resume(returning: call.form.selecting(call.selected))
        case .failed(let error): waiting.resume(throwing: fieldValues.hiding(error))
        }
    }

    private func ended(_ call: OpenCall, _ end: ScriptCall.End) {
        let purpose = call.request.purpose
        if case .form(let waiting) = purpose {
            callEnded(call.made)
            return answer(waiting, of: call, end)
        }
        if case .act(let act) = purpose {
            if case .stopped = end { act.first?.end(.stopped) } else { act.first?.end(.done) }
        }
        let isAnswer = if case .ask(let ask) = purpose { ask.isAnswer } else { false }
        if case .ended = end, failure != nil, !isAnswer, failedItem == nil || Self.item(of: call.request.message) == failedItem {
            failure = nil
            failedItem = nil
        }
        switch (purpose, end) {
        case (.ask(.show), .stopped):
            typed = nil
            list.stopLoading()
            if !call.hasAnswer {
                waiter = nil
                showsAgain = false
                sheetAgain = false
                eventAgain = nil
            }
        case (.ask(let ask), .failed(let error)):
            take(error, of: ask)
        case (.act(let act), .stopped):
            if let undo = act.undo { state = undo }
        case (.act(let act), .ended):
            answered = nil
            if act.closes, !call.showedPicture { onReport(.done) }
            if let selected = call.selected, spot.hasSheet {
                show(selecting: selected, need: .change)
            } else if !call.showedPicture, act.showsAfter {
                showOnce()
            }
        case (.act(let act), .failed(let error)):
            answered = nil
            if let undo = act.undo { state = undo }
            let item = Self.item(of: call.request.message)
            fail(error, item: item)
            if runs.isPanelOpen, let started = act.started, runs.now().timeIntervalSince(started) < MotionTokens.refusalWindow { onReport(.refused(item)) }
            if act.showsAfter { showOnce() }
        default:
            break
        }
        callEnded(call.made)
        if case .act(let act) = purpose { act.ended?() }
        if case .ask(.show) = purpose { onReport(.shown) }
        showAgainIfAsked()
    }

    static func item(of message: Message) -> String? {
        message.handler == ScriptEntry.press.name ? message.inputs.first { $0.key == itemInput }?.value : nil
    }
}
