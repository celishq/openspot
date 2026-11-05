import Foundation

/// A run of each plugin in a folder that reports all faults, so that a person or an agent can fix them.
public struct PluginCheck: Sendable {
    public let folder: PluginFolder
    public let timeout: TimeInterval

    public init(folder: PluginFolder, timeout: TimeInterval = 10) {
        self.folder = folder
        self.timeout = timeout
    }

    /// Returns one line for each fault. No lines means that all plugins load and answer.
    public func faults() async -> [String] {
        let scan: ScanResult
        do {
            scan = try folder.scan()
        } catch {
            return ["Cannot read \(folder.url.path)."]
        }
        var faults = scan.refused.map { "\($0.file): \($0.reason)" }
        for command in scan.commands {
            faults += await self.faults(of: command)
        }
        for metric in scan.metrics {
            do {
                _ = try await metric.read(timeout: timeout)
            } catch {
                faults.append("\(metric.id): \(Self.reason(error))")
            }
        }
        return faults
    }

    private func faults(of command: PluginCommand) async -> [String] {
        var faults: [String] = []
        do {
            _ = try await command.state(timeout: timeout)
            if command.kind == .list, command.search == .local {
                let lines = try await command.items(timeout: timeout)
                faults += lines.errors.map { "\(command.id): cannot read the item line \($0)" }
            }
        } catch {
            faults.append("\(command.id): \(Self.reason(error))")
        }
        return faults
    }

    private static func reason(_ error: Error) -> String {
        (error as? PluginError)?.reason ?? String(describing: error)
    }
}
