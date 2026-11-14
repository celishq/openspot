import Foundation

struct BatchCalls {
    let api: CommandAPI
    let environment: [String: String]

    func run(_ input: @escaping @Sendable () async -> String, output: CommandOutput) -> CommandAPI.Work {
        { [api, environment] in
            for line in await input().split(separator: "\n") {
                guard !Task.isCancelled else { return CommandAnswer(code: 130) }
                let words = line.split { $0 == " " || $0 == "\t" }.map(String.init)
                guard !words.isEmpty else { continue }
                guard let call = CommandLineCall(arguments: words, environment: environment), call != .batch, !Self.isRefused(call),
                      api.work(for: call, input: { "" }, environment: environment) != nil,
                      let work = api.work(for: api.admit(call, arguments: words, environment: environment), input: { "" }, environment: environment)
                else {
                    return CommandAnswer(errors: "openspot batch cannot run `\(line)`, because it does not print data. Run it on its own.\n", code: 2)
                }
                let answer = await work()
                guard answer.code == 0 else { return answer }
                output.print(answer.output + (answer.output.isEmpty || answer.output.hasSuffix("\n") ? "" : "\n") + SheetFrameReader.mark + "\n")
            }
            return CommandAnswer()
        }
    }

    private static func isRefused(_ call: CommandLineCall) -> Bool {
        switch call {
        case .clipboardCopy(nil), .translate, .colorPick, .folderPick, .screenShot, .screenRecordStart, .check, .checkJSON, .spotRun, .sandbox: true
        default: false
        }
    }
}
