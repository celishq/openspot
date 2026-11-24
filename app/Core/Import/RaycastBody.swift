import Foundation

enum RaycastBody {
    static let common = """
    clean() { LC_ALL=C sed "s/$(printf '\\033')\\[[0-9;?]*[A-Za-z]//g"; }
    launch() {
      output=$(cd "$place" 2>/dev/null || cd "$(dirname "$script")"; "$script" "$@" 2>&1 </dev/null)
      status=$?
      output=$(printf '%s\\n' "$output" | clean)
    }
    lines() { printf '%s\\n' "$output" | sed '/^[[:space:]]*$/d'; }
    fail() {
      line=$(lines | tail -n 1)
      printf '%s\\n' "${line:-The script stopped with code $status.}" >&2
      exit "$status"
    }
    """

    static let toastLast = """
    [ "$status" -eq 0 ] || fail
    line=$(lines | tail -n 1)
    [ -z "$line" ] || openspot toast "$line"
    """

    static let inline = """
    [ "$1" = show ] || exit 0
    launch
    [ "$status" -eq 0 ] || fail
    line=$(lines | head -n 1)
    printf 'frame=\\nclass=gap-part\\n'
    openspot_kv detail "$line"
    printf '\\ntext=output\\nclass=bar:flex\\n'
    openspot_kv title "$line"
    """

    static let encode = """
    encode() (
      LC_ALL=C
      rest=$1
      while [ -n "$rest" ]; do
        char=${rest%"${rest#?}"}
        rest=${rest#?}
        case "$char" in
          [A-Za-z0-9._~-]) printf '%s' "$char" ;;
          *) printf '%%%02X' "'$char" ;;
        esac
      done
    )
    """

    static func action(arguments: [RaycastArgument]) -> String {
        let numbered = number(arguments)
        var parts: [String] = []
        if arguments.contains(where: \.isEncoded) { parts.append(encode) }
        parts.append("[ \"$1\" = show ] && exit 0")
        parts += reads(numbered)
        parts.append("launch" + given(numbered))
        parts.append(toastLast)
        return parts.joined(separator: "\n")
    }

    static func sheet(arguments: [RaycastArgument], title: String, confirms: Bool) -> String {
        let numbered = number(arguments)
        let again = arguments.isEmpty && !confirms
        var parts: [String] = []
        if arguments.contains(where: \.isEncoded) { parts.append(encode) }
        parts.append(fields(numbered, title: title, confirms: confirms, again: again))
        parts.append(numbered.map { "arg\($0.number)=$(value input.arg\($0.number))" }.joined(separator: "\n"))
        parts += numbered.compactMap { one in one.argument.options.first.map { "[ -n \"$arg\(one.number)\" ] || arg\(one.number)=\(RaycastSpot.quoted($0.value))" } }
        parts.append("output() {\n  fields\n  printf '\\nfield=output\\ntype=multiline\\nreadonly=true\\n'\n  openspot_kv value \"$1\"\n}")
        let checks = numbered.filter { !$0.argument.isOptional }.map { "  " + check($0.number, $0.argument) }
        let ran = ["    launch" + given(numbered), "    output \"$output\"", "    [ \"$status\" -eq 0 ] || fail"]
        let opens = again ? ["    output 'Running…'", "    printf -- '---\\n'"] + ran : ["    fields"]
        parts.append((["case \"$1\" in", "  run)"] + checks.map { "  " + $0 } + ran + ["    ;;", "  show)"] + opens + ["    ;;", "esac"]).joined(separator: "\n"))
        return parts.joined(separator: "\n")
    }

    private static func number(_ arguments: [RaycastArgument]) -> [(number: Int, argument: RaycastArgument)] {
        Array(arguments.enumerated()).map { (number: $0.offset + 1, argument: $0.element) }
    }

    private static func reads(_ numbered: [(number: Int, argument: RaycastArgument)]) -> [String] {
        numbered.map { "arg\($0.number)=$(value input.arg\($0.number))" } + numbered.filter { !$0.argument.isOptional }.map { check($0.number, $0.argument) }
    }

    private static func check(_ number: Int, _ argument: RaycastArgument) -> String {
        "[ -n \"$arg\(number)\" ] || { echo \(RaycastSpot.quoted("Fill in \(label(number, argument)).")) >&2; exit 1; }"
    }

    private static func given(_ numbered: [(number: Int, argument: RaycastArgument)]) -> String {
        numbered.map { $0.argument.isEncoded ? " \"$(encode \"$arg\($0.number)\")\"" : " \"$arg\($0.number)\"" }.joined()
    }

    static func label(_ number: Int, _ argument: RaycastArgument) -> String {
        argument.placeholder.isEmpty ? "Argument \(number)" : argument.placeholder
    }

    static func fields(_ numbered: [(number: Int, argument: RaycastArgument)], title: String, confirms: Bool, again: Bool) -> String {
        var lines = ["fields() {", "  printf 'frame=\\nclass=gap-part\\n'"]
        if numbered.isEmpty && !again { lines += ["  printf '\\ntext=hint\\n'", "  openspot_kv title \(RaycastSpot.quoted("Press Return to run \(title)"))"] }
        for (number, argument) in numbered {
            let label = RaycastSpot.quoted(label(number, argument))
            if argument.isChoice {
                lines += ["  printf '\\nchoice=arg\(number)\\n'", "  openspot_kv title \(label)", "  openspot_kv value \"$arg\(number)\""]
                for option in argument.options {
                    lines += ["  printf '\\n'", "  openspot_kv option \(RaycastSpot.quoted(option.value))", "  openspot_kv title \(RaycastSpot.quoted(option.title))"]
                }
            } else {
                lines += ["  printf '\\nfield=arg\(number)\\n'", "  openspot_kv title \(label)", "  openspot_kv placeholder \(label)", "  openspot_kv value \"$arg\(number)\""]
            }
        }
        let button = again ? "title=Run Again\\nshortcut=cmd+r\\nscope=spot" : "title=Run\\nclass=bg-accent\\nshortcut=return"
        lines.append("  printf '\\nbutton=run\\n\(button)\\nclose=false\\n'")
        if confirms { lines.append("  printf 'confirm=Press again to run\\n'") }
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}
