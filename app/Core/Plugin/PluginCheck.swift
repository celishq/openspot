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
    @MainActor
    public func faults() async -> [String] {
        let scan: ScanResult
        do {
            scan = try folder.scan()
        } catch {
            return ["Cannot read \(folder.url.path)."]
        }
        var faults = scan.refused.map { "\($0.file): \($0.reason)" }
        let runs = SpotRuns()
        for script in scan.scripts where script.read != nil {
            do {
                let output = PluginOutput(text: try await runs.answer(of: script, .read, limit: timeout))
                _ = try script.state(of: output)
                if script.read?.seconds != nil, MetricValue(output: output) == nil { throw PluginError.badMetric }
                if script.hasSpot { faults += output.errors.map { "\(script.id): cannot read the item \($0)" } }
                faults += output.partFaults.map { "\(script.id): \($0)" }
            } catch {
                faults.append("\(script.id): \(Self.reason(error))")
            }
        }
        return faults
    }

    private static func reason(_ error: Error) -> String {
        (error as? PluginError)?.reason ?? String(describing: error)
    }
}
