import Foundation

/// A run of each plugin in a folder that reports all faults, so that a person or an agent can fix them.
public struct PluginCheck: Sendable {
    public let folder: PluginFolder
    public let timeout: TimeInterval
    public let views: ViewLibrary

    public init(folder: PluginFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard()) {
        self.folder = folder
        self.timeout = timeout
        self.views = views
    }

    /// One fault, with the spot and the file that it is in when it has them.
    public struct Finding: Equatable, Sendable, Encodable {
        public let spot: String?
        public let file: String?
        public let fault: String

        public init(spot: String?, file: String?, fault: String) {
            self.spot = spot
            self.file = file
            self.fault = fault
        }

        /// The fault in one line, after the spot that it is in.
        public var line: String {
            spot.map { "\($0): \(fault)" } ?? fault
        }
    }

    /// Returns one line for each fault. No lines means that all plugins load and answer, and each view compiles.
    @MainActor
    public func faults() async -> [String] {
        await findings().map(\.line)
    }

    /// Returns each fault with its spot and its file. None means that all plugins load and answer, and each view compiles.
    @MainActor
    public func findings() async -> [Finding] {
        let scan: ScanResult
        do {
            scan = try folder.scan()
        } catch {
            return [Finding(spot: nil, file: folder.url.path, fault: "Cannot read \(folder.url.path).")]
        }
        var findings = scan.refused.map { Finding(spot: $0.file, file: folder.file(of: $0.file)?.path, fault: $0.reason) }
        let runs = SpotRuns()
        for script in scan.scripts where script.read != nil {
            func found(_ fault: String) -> Finding { Finding(spot: script.id, file: script.url.path, fault: fault) }
            do {
                let output = PluginOutput(text: try await runs.answer(of: script, .read, limit: timeout))
                _ = try script.state(of: output)
                if script.read?.seconds != nil, MetricValue(output: output) == nil { throw PluginError.badMetric }
                if script.hasSpot { findings += output.errors.map { found("cannot read the item \($0)") } }
                findings += output.partFaults.map(found)
            } catch {
                findings.append(found(Self.reason(error)))
            }
        }
        for script in scan.scripts {
            guard let view = script.view else { continue }
            do {
                _ = try await views.library(of: URL(fileURLWithPath: view))
            } catch {
                findings.append(Finding(spot: script.id, file: view, fault: Self.reason(error)))
            }
        }
        return findings
    }

    /// The findings as one JSON list, with a new line at its end.
    public static func json(_ findings: [Finding]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: (try? encoder.encode(findings)) ?? Data("[]".utf8), as: UTF8.self) + "\n"
    }

    private static func reason(_ error: Error) -> String {
        (error as? PluginError)?.reason ?? String(describing: error)
    }
}
