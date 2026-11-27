import Foundation

public struct SpotCheck: Sendable {
    public let folder: SpotsFolder
    public let timeout: TimeInterval
    public let views: ViewLibrary
    let programs: SwiftProgram
    let callers: SpotCallers?
    let environment: [String: String]

    public init(folder: SpotsFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard(), programs: SwiftProgram = SwiftProgram(), environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.init(folder: folder, timeout: timeout, views: views, programs: programs, callers: nil, environment: environment)
    }

    init(folder: SpotsFolder, timeout: TimeInterval = 10, views: ViewLibrary = .standard(), programs: SwiftProgram = SwiftProgram(), callers: SpotCallers?, environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
        self.folder = folder
        self.timeout = timeout
        self.views = views
        self.programs = programs
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
        let compiled = scan.scripts.filter { !$0.sources.isEmpty }
        let viewed = scan.scripts.flatMap { script in script.views.values.sorted().map { (spot: script.id, view: $0) } }
        async let programFaults = Self.each(compiled) { [programs] script -> String? in
            do {
                _ = try await programs.built(script.url, with: script.sources)
                return nil
            } catch {
                return Self.reason(error)
            }
        }
        async let viewFaults = Self.each(viewed) { [views] pair -> String? in
            do {
                _ = try await views.library(of: URL(fileURLWithPath: pair.view))
                return nil
            } catch {
                return Self.reason(error)
            }
        }
        let (builds, libraries) = await (programFaults, viewFaults)
        guard !Task.isCancelled else { return findings }
        var unbuilt = Set<String>()
        for (script, fault) in zip(compiled, builds) {
            guard let fault = fault ?? nil else { continue }
            unbuilt.insert(script.id)
            findings.append(Finding(spot: script.id, file: script.url.path, fault: fault))
        }
        let runs = await SpotRuns(environment: environment, swift: programs, callers: callers ?? SpotCallers())
        for script in scan.scripts where script.hasSheet && !unbuilt.contains(script.id) {
            guard !Task.isCancelled else { return findings }
            func found(_ fault: String) -> Finding { Finding(spot: script.id, file: script.url.path, fault: fault) }
            do {
                let text = try await runs.answer(of: script, ScriptEntry.show.name, limit: timeout)
                let check = FrameCheck(text: text, kinds: script.kinds, isApp: script.isBuiltIn)
                let output = check.output
                _ = try script.state(of: output)
                if script.triggers.every != nil, MetricValue(output: output) == nil { throw SpotError.badMetric }
                findings += output.errors.map { found("cannot read the item \($0)") }
                findings += Self.brokenBlocks(in: text, kinds: script.kinds).map(found)
                findings += check.partFaults.map(found)
                findings += Self.moveFaults(of: output, in: script).map(found)
            } catch {
                findings.append(found(Self.reason(error)))
            }
        }
        for script in scan.scripts {
            for command in script.commands where FrameCheck.calls.contains(command.id) {
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
        for (pair, fault) in zip(viewed, libraries) {
            guard let fault = fault ?? nil else { continue }
            findings.append(Finding(spot: pair.spot, file: pair.view, fault: fault))
        }
        return findings
    }

    public func notes() throws -> [String] {
        try folder.scan().scripts.filter { !$0.isBuiltIn }.sorted { $0.id < $1.id }.compactMap { script in
            let ways = [
                script.url.pathExtension == "js" ? "JavaScript" : nil,
                script.url.pathExtension == "swift" ? "Swift" : nil,
                script.views.isEmpty ? nil : "its own view",
                script.mode.stays ? "stay = true" : nil
            ].compactMap { $0 }
            guard !ways.isEmpty else { return nil }
            return "\(script.id): it takes \(ways.dropLast().joined(separator: ", "))\(ways.count > 1 ? " and " : "")\(ways.last ?? ""). Say in your answer why a shell script could not do it."
        }
    }

    private static func each<Item: Sendable, Answer: Sendable>(_ items: [Item], _ work: @escaping @Sendable (Item) async -> Answer) async -> [Answer?] {
        await withTaskGroup(of: (Int, Answer).self) { group in
            var answers = [Answer?](repeating: nil, count: items.count)
            let width = max(1, ProcessInfo.processInfo.activeProcessorCount)
            var next = 0
            while next < min(width, items.count) {
                let index = next
                group.addTask { (index, await work(items[index])) }
                next += 1
            }
            while let (index, answer) = await group.next() {
                answers[index] = answer
                guard next < items.count, !Task.isCancelled else { continue }
                let added = next
                group.addTask { (added, await work(items[added])) }
                next += 1
            }
            return answers
        }
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
