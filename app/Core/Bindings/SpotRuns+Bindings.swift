import Foundation

extension SpotRuns {
    func run(_ run: BoundRun, from caller: SpotCaller, app: (any RunningApp)?) async -> RunEnd {
        let spot = caller.spot
        let binding = run.binding
        let name = run.action
        guard let sheet = sheets[binding.spot] else {
            return .failed("\(spot.name) binds \(binding.name) to the spot \(binding.spot), which is not installed. Install \(binding.spot), or remove \(binding.name) from the [bindings] of its spot.toml.")
        }
        let bound = sheet.spot
        let action: Manifest.Action
        do {
            action = try bound.action(name)
            try action.check.refuse(unknown: run.inputs.map(\.key) + (run.stdin.map { [$0.name] } ?? []))
        } catch {
            return .refused(Self.reason(error))
        }
        if let out = run.out, !action.outputs.contains(where: { $0.name == out }) {
            return .refused("\(name) has no output \(out). Its outputs are: \(action.outputs.map(\.name).joined(separator: ", ")).")
        }
        let call = caller.call?.request
        let chain = (call?.chain ?? []) + [spot.id]
        let links = (chain + [binding.spot]).joined(separator: " → ")
        if chain.contains(binding.spot) {
            return .refused("\(run.name) would run \(binding.spot) again in the chain \(links), so Openspot did not run it.")
        }
        if chain.count > Self.chainLimit {
            return .refused("\(run.name) would make the chain \(links) deeper than \(Self.chainLimit) runs, so Openspot did not run it.")
        }
        caller.holdLimit()
        runWaits[spot.id, default: 0] += 1
        if runWaits[spot.id] == 1 { sheets[spot.id]?.link.holdLimit() }
        defer {
            caller.releaseLimit()
            let left = (runWaits[spot.id] ?? 1) - 1
            runWaits[spot.id] = left > 0 ? left : nil
            if left <= 0 { sheets[spot.id]?.link.releaseLimit() }
        }
        let inputs: [TextBlock.Field]
        do {
            inputs = try action.check.checked(await run.given())
        } catch {
            return .refused(Self.reason(error))
        }
        let frame: Frame?
        do {
            frame = try await sheet.answer(to: Message(name, inputs: inputs), key: "run:\(UUID().uuidString)", chain: chain, isPressed: call?.isByPerson ?? false)
        } catch {
            return .failed(Self.reason(error))
        }
        guard let frame else { return .unanswered("\(run.name) stopped before it answered.") }
        if !frame.outputs.isEmpty { return .values(frame.outputs) }
        if frame.isPicture {
            guard call?.isByPerson == true else {
                let handler = call?.handler ?? "a handler"
                return .refused("\(run.name) answers with a view, which needs the person, and \(spot.name) runs \(handler) with no press. Show a toast or open a float instead.")
            }
            guard let app else { return .failed("\(run.name) answers with a view, and no app shows it.") }
            return await push(frame, of: sheet, for: action, from: spot, app: app)
        }
        return action.outputs.isEmpty ? .values([]) : .unanswered("\(run.name) answered with no values.")
    }

    private func push(_ frame: Frame, of sheet: SpotRun, for action: Manifest.Action, from spot: Spot, app: any RunningApp) async -> RunEnd {
        let id = sheet.spot.id
        await sheet.hold(frame)
        let end = await withCheckedContinuation { waiting in
            pushed.wait(for: id, action: action, waiting)
            Task { [weak self] in
                if await !app.ask(id, from: spot.id, title: frame.root?.value(RootKey.title)) { self?.pushed.end(id, .failed("Openspot cannot show \(sheet.spot.name).")) }
            }
        }
        sheet.release()
        if end != .cancelled { _ = await app.leave(id) }
        return end
    }

    static let chainLimit = 4

    func waitsInRun(_ id: String) -> Bool {
        runWaits[id] != nil
    }

    func answerPushed(_ lines: Frame, from id: String) {
        pushed.answer(lines, from: id)
    }

    func settlePushed(of id: String) {
        guard pushed.isWaiting(for: id), let sheet = sheets[id], !sheet.showsSheet, sheet.calls.allSatisfy(\.isStopped) else { return }
        pushed.end(id, .cancelled)
    }

    func emit(_ event: String, values: [TextBlock.Field], from spot: Spot) {
        for sheet in sheets.values {
            for binding in sheet.spot.bindings where binding.spot == spot.id {
                let heard = Manifest.BoundEvent(binding: binding.name, event: event)
                if sheet.spot.triggers.bindings.contains(heard) { sheet.trigger(Message(heard.key, inputs: values), key: "\(Manifest.Triggers.table).\(heard.key)") }
            }
        }
    }

    nonisolated static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
