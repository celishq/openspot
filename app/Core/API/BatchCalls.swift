import Foundation

/// The call of `openspot batch`: one call for each line of stdin, with its words split at spaces, run in turn in one
/// process (K7). It prints the output of each call and then a line `---`, and stops at the first call that fails, or once
/// its caller stops it. It runs no call that the app leaves to a process of its own, that reads stdin, or that can wait for
/// the person.
struct BatchCalls {
    let api: CommandAPI
    let environment: [String: String]

    func run(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        { [api, environment] in
            var output = ""
            for line in await input().split(separator: "\n") {
                guard !Task.isCancelled else { return CommandAnswer(output: output, code: 130) }
                let words = line.split { $0 == " " || $0 == "\t" }.map(String.init)
                guard !words.isEmpty else { continue }
                guard let call = CommandLineCall(arguments: words, environment: environment), call != .batch, !Self.isRefused(call),
                      api.work(for: call, input: { "" }, environment: environment) != nil,
                      let work = api.work(for: api.admit(call, arguments: words, environment: environment), input: { "" }, environment: environment)
                else {
                    return CommandAnswer(output: output, errors: "openspot batch cannot run `\(line)`, because it does not print data. Run it on its own.\n", code: 2)
                }
                let answer = await work()
                guard answer.code == 0 else { return CommandAnswer(output: output + answer.output, errors: answer.errors, code: answer.code) }
                output += answer.output + (answer.output.isEmpty || answer.output.hasSuffix("\n") ? "" : "\n") + SheetFrameReader.mark + "\n"
            }
            return CommandAnswer(output: output)
        }
    }

    /// Whether a call reads stdin, which a batch holds, or can wait for the person, such as a pick of a colour.
    private static func isRefused(_ call: CommandLineCall) -> Bool {
        switch call {
        case .clipboardCopy(nil), .translate, .colorPick, .folderPick, .screenShot, .screenRecordStart: true
        default: false
        }
    }
}
