import Foundation

/// A run of each plugin in a folder that reports all faults, so that a person or an agent can fix them.
public struct SpotCheck: Sendable {
    public let folder: SpotFolder
    public let timeout: TimeInterval
    public let views: ViewLibrary

    public init(folder: SpotFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard()) {
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
                let text = try await runs.answer(of: script, .read, limit: timeout)
                let output = SpotOutput(text: text)
                _ = try script.state(of: output)
                if script.read?.seconds != nil, MetricValue(output: output) == nil { throw SpotError.badMetric }
                findings += output.errors.map { found("cannot read the item \($0)") }
                findings += Self.brokenBlocks(in: text).map(found)
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

    /// The faults of blocks that a value with a new line breaks: a line with no `=`, or a key twice that only a list repeats
    /// (C8).
    static func brokenBlocks(in text: String) -> [String] {
        let fix = "as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc"
        let lists: Set<String> = ["grid", "value", "hides", "keyword", "color"]
        var faults: [String] = []
        let blocks = text.components(separatedBy: "\n").split { $0.isEmpty || $0 == SheetFrameReader.mark }
        for block in blocks {
            let name = block.first ?? ""
            if block.contains(where: { !$0.contains("=") }) { faults.append("the block \(name) has a line with no =, \(fix)") }
            var seen: Set<String> = []
            var told: Set<String> = []
            for line in block {
                guard let key = line.split(separator: "=", maxSplits: 1).first.map(String.init), !lists.contains(key), !key.hasPrefix("grid.") else { continue }
                if !seen.insert(key).inserted, told.insert(key).inserted { faults.append("the block \(name) has \(key) twice, \(fix)") }
            }
        }
        return faults
    }

    private static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? String(describing: error)
    }
}
