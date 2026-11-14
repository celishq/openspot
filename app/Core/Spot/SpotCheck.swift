import Foundation

public struct SpotCheck: Sendable {
    public let folder: SpotsFolder
    public let timeout: TimeInterval
    public let views: ViewLibrary
    let careful: Set<SpotUse>?
    let tokens: CallerTokens?

    public init(folder: SpotsFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard()) {
        self.init(folder: folder, timeout: timeout, views: views, careful: nil, tokens: nil)
    }

    init(folder: SpotsFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard(), careful: Set<SpotUse>?, tokens: CallerTokens?) {
        self.folder = folder
        self.timeout = timeout
        self.views = views
        self.careful = careful
        self.tokens = tokens
    }

    public struct Finding: Equatable, Sendable, Encodable {
        public let spot: String?
        public let file: String?
        public let fault: String

        public init(spot: String?, file: String?, fault: String) {
            self.spot = spot
            self.file = file
            self.fault = fault
        }

        public var line: String {
            spot.map { "\($0): \(fault)" } ?? fault
        }
    }

    public func faults() async -> [String] {
        await findings().map(\.line)
    }

    public func findings() async -> [Finding] {
        let scan: ScanResult
        do {
            scan = try folder.scan()
        } catch {
            return [Finding(spot: nil, file: folder.url.path, fault: "Cannot read \(folder.url.path).")]
        }
        var findings = scan.refused.map { Finding(spot: $0.file, file: SpotID($0.file).file(in: folder.url)?.path, fault: $0.reason) }
        let known = Set(SpotEvent.known + scan.scripts.flatMap(\.emits))
        for script in scan.scripts {
            for event in script.read?.events ?? [] where !known.contains(event) {
                let fault = "\(script.name) reads on \(event), which Openspot does not raise and no spot names in its emits. Add emits=\(event) to the spot that raises it, or fix the name"
                findings.append(Finding(spot: script.id, file: script.url.path, fault: fault))
            }
            for event in script.read?.events ?? [] where script.emits.contains(event) {
                let fault = "\(script.name) reads on \(event) and raises it, so a raise from its read would read it again without end. Raise it from an action, or rename one of them"
                findings.append(Finding(spot: script.id, file: script.url.path, fault: fault))
            }
        }
        let runs = await SpotRuns(tokens: tokens ?? CallerTokens())
        if careful != nil { await MainActor.run { runs.isCareful = true } }
        for var script in scan.scripts where script.read != nil {
            guard !Task.isCancelled else { return findings }
            if let careful { script.uses.formIntersection(careful) }
            func found(_ fault: String) -> Finding { Finding(spot: script.id, file: script.url.path, fault: fault) }
            do {
                let text = try await runs.answer(of: script, .read, limit: timeout)
                let output = SpotOutput(text: text)
                _ = try script.state(of: output)
                if script.read?.seconds != nil, MetricValue(output: output) == nil { throw SpotError.badMetric }
                findings += output.retired.map(found)
                findings += output.unreadable.map { found("cannot read the item \($0)") }
                findings += Self.brokenBlocks(in: text).map(found)
                findings += output.partFaults.map(found)
                findings += Self.moveFaults(of: output, in: script, among: scan.scripts).map(found)
            } catch {
                findings.append(found(Self.reason(error)))
            }
        }
        for script in scan.scripts {
            guard !Task.isCancelled else { return findings }
            guard let view = script.view else { continue }
            do {
                _ = try await views.library(of: URL(fileURLWithPath: view))
            } catch {
                findings.append(Finding(spot: script.id, file: view, fault: Self.reason(error)))
            }
        }
        return findings
    }

    static func moveFaults(of output: SpotOutput, in script: Spot, among scripts: [Spot]) -> [String] {
        var faults: [String] = []
        if let move = output.move {
            let word = if case .pop = move { "pop" } else { "push" }
            faults.append("the read prints \(word), which moves nothing in a read. Print it from a press")
        }
        for item in output.items {
            guard case .push(let spot, let page?, _, _)? = item.move else { continue }
            let target = spot ?? script.id
            guard let taker = scripts.first(where: { $0.id == target }), !taker.takes(page: page) else { continue }
            let pattern = page.firstIndex(of: ":").map { "\(page[..<$0]):*" } ?? page
            faults.append("the row \(item.run) pushes the page \(page) of \(target), which takes no such page. Add pages=\(pattern) to \(target)")
        }
        return faults
    }

    public static func json(_ findings: [Finding]) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return String(decoding: (try? encoder.encode(findings)) ?? Data("[]".utf8), as: UTF8.self) + "\n"
    }

    static func brokenBlocks(in text: String) -> [String] {
        let fix = "as a value with a new line prints. Print each value from data with openspot_kv, openspot_row or esc"
        let lists: Set<String> = ["grid", "value", "hides", "color"]
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
