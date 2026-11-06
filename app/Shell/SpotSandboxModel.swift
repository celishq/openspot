import Foundation
import Observation
import OpenspotCore

/// The state of the sandbox window. It reads a sheet from typed text, a file it watches, or a script that it runs.
@MainActor
@Observable
final class SpotSandboxModel {
    private static let watchPause: Duration = .milliseconds(500)
    private static let callTimeout: TimeInterval = 30
    private static let textPause: Duration = .milliseconds(300)
    private static let sliderPause: Duration = .milliseconds(100)

    private(set) var sandbox = SheetSandbox()
    private(set) var script: PluginCommand?
    let file: URL?
    @ObservationIgnored private var written: Date?
    @ObservationIgnored private var call: Task<Void, Never>?

    var fileName: String? {
        file?.lastPathComponent
    }

    /// Whether the left side is a script's answer, which a person does not edit here.
    var isScript: Bool {
        script != nil
    }

    init(path: String?) {
        file = path.map { URL(fileURLWithPath: $0) }
        if let file, FileManager.default.isExecutableFile(atPath: file.path) {
            script = PluginCommand(id: file.lastPathComponent, name: file.lastPathComponent, url: file, kind: .list)
        }
        reload()
        watch()
    }

    nonisolated deinit {}

    /// Takes text that a person typed, and saves it when the sandbox has a file.
    func edit(_ text: String) {
        sandbox.take(text: text)
        guard let file, script == nil else { return }
        try? text.write(to: file, atomically: true, encoding: .utf8)
        written = Self.modified(file)
    }

    func set(_ part: SpotPart, to value: String) {
        let generation = sandbox.set(value, of: part.id)
        guard let script else { return }
        let pause: Duration? = switch part.control {
        case .text: Self.textPause
        case .slider: Self.sliderPause
        default: nil
        }
        run(.set(part.id, to: value), on: script, generation: generation, pause: pause, keeping: part.isEditable ? part.id : nil)
    }

    func press(_ part: SpotPart) {
        let generation = sandbox.press(part.id)
        guard let script else { return }
        run(.press(part.id), on: script, generation: generation)
    }

    private func run(_ action: SpotAction, on script: PluginCommand, generation: Int, pause: Duration? = nil, keeping: String? = nil) {
        call?.cancel()
        call = Task {
            if let pause { try? await Task.sleep(for: pause) }
            guard !Task.isCancelled else { return }
            do {
                let answer = try await PluginRun(command: script, arguments: action.arguments, timeout: Self.callTimeout, input: sandbox.panel?.values).output()
                guard !Task.isCancelled else { return }
                if answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    reload()
                } else {
                    sandbox.take(answer: answer, answering: generation, keeping: keeping)
                }
            } catch {
                sandbox.record("failed: \((error as? PluginError)?.reason ?? String(describing: error))")
            }
        }
    }

    /// Reads the file or runs the script again.
    private func reload() {
        guard let file else { return }
        written = Self.modified(file)
        guard let script else {
            sandbox.take(text: (try? String(contentsOf: file, encoding: .utf8)) ?? "")
            return
        }
        Task {
            do {
                let answer = try await PluginRun(command: script, arguments: [], timeout: Self.callTimeout, input: sandbox.panel?.values).output()
                sandbox.take(text: answer)
            } catch {
                sandbox.record("failed: \((error as? PluginError)?.reason ?? String(describing: error))")
            }
        }
    }

    /// Reads the file again each time something else changes it, such as a model that writes there.
    private func watch() {
        guard let file else { return }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.watchPause)
                guard let self else { return }
                if Self.modified(file) != self.written { self.reload() }
            }
        }
    }

    private static func modified(_ file: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: file.path))?[.modificationDate] as? Date
    }
}
