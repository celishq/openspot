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
        guard let action = bound.typedActions.first(where: { $0.id == name }) else {
            let names = bound.typedActions.map(\.id)
            return .refused("\(bound.name) has no action \(name). " + (names.isEmpty ? "It declares no [actions]." : "Name one of its [actions]: \(names.joined(separator: ", "))."))
        }
        let declared = action.inputs.map(\.name)
        if let unknown = (run.inputs.map(\.key) + (run.stdin.map { [$0.name] } ?? [])).first(where: { !declared.contains($0) }) {
            return .refused("\(name) has no input \(unknown). Its inputs are: \(declared.joined(separator: ", ")).")
        }
        if let out = run.out, !action.outputs.contains(where: { $0.name == out }) {
            return .refused("\(name) has no output \(out). Its outputs are: \(action.outputs.map(\.name).joined(separator: ", ")).")
        }
        caller.holdLimit()
        defer { caller.releaseLimit() }
        let inputs: [TextBlock.Field]
        do {
            inputs = try action.inputs(await run.given())
        } catch {
            return .refused(Self.reason(error))
        }
        let call = caller.call?.request
        let chain = (call?.chain ?? []) + [spot.id]
        let frame: Frame?
        do {
            frame = try await sheet.answer(to: Message(.press(name), inputs: inputs), key: "run:\(UUID().uuidString)", chain: chain, isPressed: call?.isByPerson ?? false)
        } catch {
            return .failed(Self.reason(error))
        }
        guard let frame else { return .unanswered("\(run.name) stopped before it answered.") }
        if !frame.outputs.isEmpty { return .values(frame.outputs) }
        if frame.isPicture {
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
                if await !app.ask(id, from: spot.id, title: nil) { self?.pushed.end(id, .failed("Openspot cannot show \(sheet.spot.name).")) }
            }
        }
        sheet.release()
        if end != .cancelled { _ = await app.leave(id) }
        return end
    }

    func answerPushed(_ lines: Frame, from id: String) {
        pushed.answer(lines, from: id)
    }

    func settlePushed(of id: String) {
        guard pushed.isWaiting(for: id), let sheet = sheets[id], !sheet.isOpen, sheet.calls.allSatisfy(\.isStopped) else { return }
        pushed.end(id, .cancelled)
    }

    func emit(_ event: String, values: [TextBlock.Field], from spot: Spot) {
        for sheet in sheets.values {
            for binding in sheet.spot.bindings where binding.spot == spot.id {
                let handler = "\(binding.name).\(event)"
                if sheet.spot.triggers?.bindings.contains(handler) == true { sheet.hear(handler, values: values) }
            }
        }
    }

    nonisolated static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? error.localizedDescription
    }
}
