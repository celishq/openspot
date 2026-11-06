import Foundation
import Observation

/// The sheet of one spot: its rows, its parts and the runs of its script that fill them. Each spot has its own, so a run
/// of one never stops a run of another, and a stopped run changes nothing.
@MainActor
@Observable
public final class SpotSheet {
    /// What the sheet tells its owner.
    public enum Report: Sendable {
        case toast(String)
        case failure(String)
        case output(PluginOutput)
        case frame(String)
        case listChange
    }

    private static let actionTimeout: TimeInterval = 30
    private static let itemsTimeout: TimeInterval = 10
    private static let searchTimeout: TimeInterval = 10
    private static let textPause: Duration = .milliseconds(300)
    private static let sliderPause: Duration = .milliseconds(100)

    public private(set) var command: PluginCommand
    public var list: ItemList {
        didSet { onReport(.listChange) }
    }
    public private(set) var panel: SpotPanel?
    public private(set) var isOpen = false
    @ObservationIgnored public var onReport: (Report) -> Void = { _ in }
    @ObservationIgnored private let prepare: ([SpotItem]) async -> Void
    @ObservationIgnored private var reading: Task<Void, Never>?
    @ObservationIgnored private var isStreaming = false
    @ObservationIgnored private var changing: Task<Void, Never>?
    @ObservationIgnored private var nextRead: Task<Void, Never>?
    @ObservationIgnored private var searching: Task<Void, Never>?
    @ObservationIgnored private var live: LiveScript?
    @ObservationIgnored private var editing: String?
    @ObservationIgnored private var ready: (() -> Void)?

    public init(command: PluginCommand, recent: [String] = [], prepare: @escaping ([SpotItem]) async -> Void = { _ in }) {
        self.command = command
        self.prepare = prepare
        list = ItemList(recent: recent)
    }

    nonisolated deinit {}

    /// Takes the command again after a new look at the plugin folder.
    public func update(_ command: PluginCommand) {
        self.command = command
    }

    /// Opens the sheet with its search kept. `onReady` runs now, or for a staying script with its first frame.
    public func open(onReady: @escaping () -> Void) {
        isOpen = true
        list.selectFirst()
        if command.stays {
            ready = onReady
            startLive()
            return
        }
        onReady()
        read()
    }

    /// Stops what only an open sheet needs. A read that has given no frame yet goes on, and fills its list.
    public func close() {
        isOpen = false
        searching?.cancel()
        changing?.cancel()
        nextRead?.cancel()
        stopStream()
        live?.stop()
        live = nil
        editing = nil
        ready = nil
        panel?.clearSelection()
    }

    /// Moves the selection among its parts.
    public func movePart(by step: Int) {
        panel?.move(by: step)
    }

    /// Asks the script for its rows and parts. A newer read replaces this one. A script that keeps printing changes its open
    /// sheet until a newer call or the end of the sheet stops it. A staying script answers only while its sheet is open.
    public func read(selecting run: String? = nil) {
        guard command.kind == .list else { return }
        if command.stays {
            if isOpen { startLive() }
            return
        }
        guard list.search == .local else { return ask() }
        list.beginLoading()
        reading?.cancel()
        isStreaming = false
        reading = Task {
            var isFirst = true
            do {
                for try await text in command.frames(.items(query: ""), input: panel?.values, timeout: Self.itemsTimeout) {
                    guard !Task.isCancelled else { return }
                    let lines = PluginOutput(text: text)
                    if isFirst {
                        await takeItems(lines, frame: text, selecting: run)
                        guard !Task.isCancelled else { return }
                        isFirst = false
                        isStreaming = true
                    } else {
                        guard isOpen else { break }
                        if let toast = lines.summary?.value("toast") { onReport(.toast(toast)) }
                        panel?.merge(lines)
                        onReport(.frame(text))
                    }
                }
                guard !Task.isCancelled else { return }
                if isFirst { await takeItems(PluginOutput(text: ""), frame: "", selecting: run) }
                isStreaming = false
            } catch {
                guard !Task.isCancelled else { return }
                isStreaming = false
                list.loadFailed()
                fail(error)
            }
        }
    }

    /// Takes new text in the search, and asks the script about it when the script searches.
    public func search(_ text: String) {
        if list.search(text), list.search == .script { ask() }
    }

    /// Takes a value the person set, so that it shows at once, and tells the script after a pause that fits the control.
    public func set(_ part: SpotPart, to value: String) {
        guard let generation = panel?.set(value, of: part.id) else { return }
        if part.isEditable { editing = part.id }
        let pause: Duration? = switch part.control {
        case .text: Self.textPause
        case .slider: Self.sliderPause
        default: nil
        }
        change(.set(part.id, to: value), generation: generation, pause: pause, keeping: part.isEditable ? part.id : nil)
    }

    public func press(_ part: SpotPart) {
        guard let generation = panel?.advance() else { return }
        editing = nil
        change(.press(part.id), generation: generation, closes: part.closes)
    }

    private func takeItems(_ lines: PluginOutput, frame: String, selecting run: String?) async {
        keep(lines)
        list.take(search: lines.search)
        takePanel(lines)
        list.replace(lines.items)
        if let run { list.select(run: run) }
        if list.search == .script, !list.query.isEmpty { ask() }
        onReport(.frame(frame))
        await prepare(lines.items)
        if !lines.errors.isEmpty {
            onReport(.failure("\(command.name) sent \(lines.errors.count) items Openspot cannot read."))
        }
    }

    /// Keeps the actions a script printed.
    private func keep(_ output: PluginOutput) {
        command = command.taking(output)
        onReport(.output(output))
    }

    /// Shows the parts a script printed, and keeps them fresh when it asks for that.
    private func takePanel(_ lines: PluginOutput) {
        if let generation = panel?.generation {
            guard panel?.take(lines, answering: generation) == true else { return }
        } else {
            panel = SpotPanel(output: lines)
        }
        readAgain()
    }

    /// Reads an open sheet of parts again after the time it asks for.
    private func readAgain() {
        nextRead?.cancel()
        guard isOpen, let every = panel?.every else { return }
        nextRead = Task {
            try? await Task.sleep(for: .seconds(every))
            if !Task.isCancelled { read() }
        }
    }

    private func stopStream() {
        if isStreaming { reading?.cancel() }
        isStreaming = false
    }

    /// Asks a staying script for its sheet, and starts the script if it is not running. A new run gets no values.
    private func startLive() {
        var values = panel?.values
        if live == nil {
            values = nil
            let script = LiveScript(url: command.url, timeout: Self.itemsTimeout)
            do {
                let frames = try script.start()
                live = script
                Task { await follow(script, frames) }
            } catch {
                return fail(error)
            }
        }
        live?.send(.read, values: values)
    }

    /// Takes each frame of a staying script until it ends. Its first frame replaces what an earlier run left.
    private func follow(_ script: LiveScript, _ frames: AsyncThrowingStream<String, Error>) async {
        var isFirst = true
        do {
            for try await text in frames {
                guard live === script else { return }
                let lines = PluginOutput(text: text)
                if let toast = lines.summary?.value("toast") { onReport(.toast(toast)) }
                keep(lines)
                if isFirst {
                    panel = SpotPanel(output: lines)
                    isFirst = false
                    ready?()
                    ready = nil
                } else {
                    panel?.merge(lines, keeping: editing)
                }
                onReport(.frame(text))
            }
        } catch {
            if live === script { fail(error) }
        }
        if live === script { live = nil }
    }

    /// Asks the script about the current search. A newer search stops the older one.
    private func ask() {
        let query = list.query
        searching?.cancel()
        searching = Task {
            do {
                let lines = try await command.items(query: query, timeout: Self.searchTimeout)
                await prepare(lines.items)
                guard !Task.isCancelled else { return }
                keep(lines)
                list.take(search: lines.search)
                list.answer(lines.items, to: query)
            } catch {
                guard !Task.isCancelled else { return }
                list.stopWaiting(for: query)
                if error as? PluginError != .timedOut { fail(error) }
            }
        }
    }

    /// Runs one change of a sheet of parts. A newer change stops it, and only the newest answer shows. A script that prints
    /// no parts is read again. A staying script takes the change as a block.
    private func change(_ action: SpotAction, generation: Int, pause: Duration? = nil, keeping: String? = nil, closes: Bool = false) {
        changing?.cancel()
        stopStream()
        if command.stays, pause == nil {
            live?.send(action, values: panel?.values)
            return
        }
        changing = Task {
            if let pause { try? await Task.sleep(for: pause) }
            guard !Task.isCancelled, let values = panel?.values else { return }
            if command.stays {
                live?.send(action, values: values)
                return
            }
            var isFirst = true
            do {
                for try await text in command.frames(action, input: values, timeout: Self.actionTimeout) {
                    guard !Task.isCancelled || closes else { return }
                    let lines = PluginOutput(text: text)
                    if let toast = lines.summary?.value("toast") { onReport(.toast(toast)) }
                    if isFirst, lines.parts.isEmpty, !closes {
                        read()
                    } else if isFirst {
                        panel?.take(lines, answering: generation, keeping: keeping)
                    } else {
                        panel?.merge(lines, answering: generation, keeping: keeping)
                    }
                    onReport(.frame(text))
                    isFirst = false
                }
                guard !Task.isCancelled else { return }
                if isFirst, !closes { read() }
            } catch {
                guard !Task.isCancelled else { return }
                fail(error)
                read()
            }
        }
    }

    private func fail(_ error: Error) {
        onReport(.failure("\(command.name) failed. \((error as? PluginError)?.reason ?? error.localizedDescription)"))
    }
}
