import Foundation

public struct SpotCheck: Sendable {
    public let folder: SpotsFolder
    public let timeout: TimeInterval
    public let views: ViewLibrary
    let programs: SwiftProgram
    let careful: Set<SpotUse>?
    let callers: SpotCallers?
    let environment: [String: String]

    public init(folder: SpotsFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard(), programs: SwiftProgram = SwiftProgram(), environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.init(folder: folder, timeout: timeout, views: views, programs: programs, careful: nil, callers: nil, environment: environment)
    }

    init(folder: SpotsFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard(), programs: SwiftProgram = SwiftProgram(), careful: Set<SpotUse>?, callers: SpotCallers?, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        self.folder = folder
        self.timeout = timeout
        self.views = views
        self.programs = programs
        self.careful = careful
        self.callers = callers
    }

    public struct Finding: Equatable, Sendable, PrintedRecord {
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

        var blocks: [[(String, String?)]] {
            [[("fault", fault), ("spot", spot), ("file", file)]]
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
            for event in script.on?.events ?? [] where !known.contains(event) {
                let fault = "\(script.name) reads on \(event), which Openspot does not raise and no spot names in its emits. Add emits = [\"\(event)\"] to the spot that raises it, or fix the name"
                findings.append(Finding(spot: script.id, file: script.url.path, fault: fault))
            }
            for event in script.on?.events ?? [] where script.emits.contains(event) {
                let fault = "\(script.name) reads on \(event) and raises it, so a raise from its read would read it again without end. Raise it from an action, or rename one of them"
                findings.append(Finding(spot: script.id, file: script.url.path, fault: fault))
            }
        }
        var unbuilt = Set<String>()
        for script in scan.scripts where !script.sources.isEmpty {
            guard !Task.isCancelled else { return findings }
            do {
                _ = try await programs.built(script.url, with: script.sources)
            } catch {
                unbuilt.insert(script.id)
                findings.append(Finding(spot: script.id, file: script.url.path, fault: Self.reason(error)))
            }
        }
        let runs = await SpotRuns(environment: environment, swift: programs, callers: callers ?? SpotCallers())
        if careful != nil { await MainActor.run { runs.isCareful = true } }
        for var script in scan.scripts where script.hasSheet && !unbuilt.contains(script.id) {
            guard !Task.isCancelled else { return findings }
            if let careful { script.uses.formIntersection(careful) }
            func found(_ fault: String) -> Finding { Finding(spot: script.id, file: script.url.path, fault: fault) }
            do {
                let text = try await runs.answer(of: script, .show, limit: timeout)
                let check = FrameCheck(text: text, kinds: script.kinds, isApp: script.isBuiltIn)
                let output = check.output
                _ = try script.state(of: output)
                if script.on?.seconds != nil, MetricValue(output: output) == nil { throw SpotError.badMetric }
                findings += output.errors.map { found("cannot read the item \($0)") }
                findings += Self.brokenBlocks(in: text, kinds: script.kinds).map(found)
                findings += check.partFaults.map(found)
                findings += Self.moveFaults(of: output, in: script).map(found)
            } catch {
                findings.append(found(Self.reason(error)))
            }
        }
        for script in scan.scripts {
            for command in script.offers where FrameCheck.calls.contains(command.id) {
                findings.append(Finding(spot: script.id, file: script.url.path, fault: "a command cannot be called \(command.id), since Openspot calls the spot with \(command.id)"))
            }
        }
        for script in scan.scripts where !script.isBuiltIn {
            guard (try? Manifest(beside: script.url).script(script.url))?.uses.contains(SpotUse.account.rawValue) == true else { continue }
            let fault = "\(script.name) has account in its uses, which only a spot of Openspot takes. Remove it"
            findings.append(Finding(spot: script.id, file: script.url.path, fault: fault))
        }
        for script in scan.scripts {
            for (kind, view) in script.views.sorted(by: { $0.key < $1.key }) where BlockKind.words.contains(kind) {
                let fault = "the view \(URL(fileURLWithPath: view).lastPathComponent) has the name of the kind \(kind), so a \(kind) block never reaches it. Rename the file"
                findings.append(Finding(spot: script.id, file: view, fault: fault))
            }
        }
        for script in scan.scripts {
            guard !Task.isCancelled else { return findings }
            for view in script.views.values.sorted() {
                do {
                    _ = try await views.library(of: URL(fileURLWithPath: view))
                } catch {
                    findings.append(Finding(spot: script.id, file: view, fault: Self.reason(error)))
                }
            }
        }
        return findings
    }

    static func moveFaults(of output: Frame, in script: Spot) -> [String] {
        var faults: [String] = []
        for item in output.items {
            guard case .push(_, let page?, _, _)? = item.move, !script.takes(route: page) else { continue }
            let pattern = page.firstIndex(of: ":").map { "\(page[..<$0]):*" } ?? page
            faults.append("the row \(item.run) pushes the page \(page) of \(script.id), which takes no such page. Add pages = [\"\(pattern)\"] to \(script.id)")
        }
        return faults
    }

    public static func json(_ findings: [Finding]) -> String {
        (try? PrintForm.json(findings)) ?? "[]\n"
    }

    static func brokenBlocks(in text: String, kinds: [BlockKind] = BlockKind.all) -> [String] {
        let fix = "as a value with a new line prints. Print each value from data with openspot_kv, openspot_item or esc"
        let lists: Set<String> = ["value", "hides", "color"]
        var faults: [String] = []
        let blocks = text.components(separatedBy: "\n").split { $0.isEmpty || $0 == SheetFrames.mark }
        let views = Set(kinds.filter { $0.source != nil }.map(\.word))
        for block in blocks {
            let name = block.first ?? ""
            let isView = views.contains(name.split(separator: "=", maxSplits: 1).first.map(String.init) ?? "")
            if block.contains(where: { !$0.contains("=") }) { faults.append("the block \(name) has a line with no =, \(fix)") }
            var seen: Set<String> = []
            var told: Set<String> = []
            for line in block {
                guard let key = line.split(separator: "=", maxSplits: 1).first.map(String.init) else { continue }
                guard isView ? ViewNode.commonKeys.contains(key) : !lists.contains(key) else { continue }
                if !seen.insert(key).inserted, told.insert(key).inserted { faults.append("the block \(name) has \(key) twice, \(fix)") }
            }
        }
        return faults
    }

    private static func reason(_ error: Error) -> String {
        (error as? SpotError)?.reason ?? String(describing: error)
    }
}
