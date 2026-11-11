import Foundation

/// The call of `openspot batch`: one call for each line of stdin, with its words split at spaces, run in turn in one
/// process (K7). It prints the output of each call and then a line `---`, and stops at the first call that fails.
struct BatchCalls {
    let api: CommandAPI
    let environment: [String: String]

    func run(_ input: @escaping @Sendable () async -> String) -> CommandAPI.Work {
        { [api, environment] in
            var output = ""
            for line in await input().split(separator: "\n") {
                let words = line.split { $0 == " " || $0 == "\t" }.map(String.init)
                guard !words.isEmpty else { continue }
                guard let call = CommandLineCall(arguments: words, environment: environment), call != .batch,
                      let work = api.work(for: call, input: { "" }, environment: environment)
                else {
                    return CommandAnswer(output: output, errors: "openspot batch cannot run `\(line)`, because it does not print data. Run it on its own.\n", code: 2)
                }
                api.note(call, arguments: words, environment: environment)
                let answer = await work()
                guard answer.code == 0 else { return CommandAnswer(output: output + answer.output, errors: answer.errors, code: answer.code) }
                output += answer.output + (answer.output.isEmpty || answer.output.hasSuffix("\n") ? "" : "\n") + SheetFrameReader.mark + "\n"
            }
            return CommandAnswer(output: output)
        }
    }
}
