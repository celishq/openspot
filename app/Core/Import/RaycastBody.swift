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
    [ -z "$line" ] || openspot_kv toast "$line"
    """

    static var toast: String {
        """
        [ "$1" = read ] && exit 0
        launch
        \(toastLast)
        """
    }

    static let inline = """
    [ "$1" = read ] || exit 0
    launch
    [ "$status" -eq 0 ] || fail
    line=$(lines | head -n 1)
    openspot_kv detail "$line"
    printf '\\ntext=output\\n'
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

    static func sheet(arguments: [RaycastArgument], title: String, mode: RaycastScript.Mode, confirms: Bool) -> String {
        let numbered = Array(arguments.enumerated()).map { (number: $0.offset + 1, argument: $0.element) }
        var parts: [String] = []
        if arguments.contains(where: \.isEncoded) { parts.append(encode) }
        parts += numbered.filter { $0.argument.isChoice }.map { pick($0.number, $0.argument) }
        parts.append(fields(numbered, title: title, confirms: confirms, closes: mode == .silent, again: mode == .fullOutput && arguments.isEmpty && !confirms))
        parts.append((["slash="] + numbered.map { "arg\($0.number)=$(value arg\($0.number))" }).joined(separator: "\n"))
        let shows = mode == .fullOutput
        let output = "printf '\\nfield=output\\ntype=multiline\\nreadonly=true\\n'\nopenspot_kv value \"$1\""
        parts.append("output() {\n  fields output\n" + output.split(separator: "\n").map { "  \($0)" }.joined(separator: "\n") + "\n}")
        let given = numbered.map { $0.argument.isEncoded ? "\"$(encode \"$arg\($0.number)\")\"" : "\"$arg\($0.number)\"" }.joined(separator: " ")
        let checks = numbered.filter { !$0.argument.isOptional }.map {
            "    [ -n \"$arg\($0.number)\" ] || { echo \(RaycastSpot.quoted("Fill in \(label($0.number, $0.argument)).")) >&2; exit 1; }"
        }
        let values = numbered.filter { $0.argument.isChoice }.map { "    arg\($0.number)=$(pick\($0.number) \"$arg\($0.number)\")" }
        let ran = shows ? "    output \"$output\"\n    [ \"$status\" -eq 0 ] || fail" : toastLast.split(separator: "\n").map { "    \($0)" }.joined(separator: "\n")
        let filled = numbered.filter { !$0.argument.isOptional }.map { "[ -n \"$arg\($0.number)\" ]" }
        let marks = "    [ -z \"$(value search)\" ] || { \((filled.isEmpty ? ["true"] : filled).joined(separator: " && ")) && slash=1; }"
        let first = numbered.isEmpty ? nil : spread(numbered) + (confirms ? "" : "\n" + marks)
        let opens = shows && arguments.isEmpty && !confirms
            ? "    output 'Running…'\n    printf -- '---\\n'\n    launch\n    output \"$output\"\n    [ \"$status\" -eq 0 ] || fail"
            : "    fields"
        parts.append((["case \"$1\" in", "  run)"] + checks + values + ["    launch" + (given.isEmpty ? "" : " \(given)"), ran, "    ;;", "  read)"]
            + (first.map { [$0] } ?? []) + [opens, "    ;;", "esac"]).joined(separator: "\n"))
        return parts.joined(separator: "\n")
    }

    static func spread(_ numbered: [(number: Int, argument: RaycastArgument)]) -> String {
        guard numbered.count > 1 else {
            return numbered[0].argument.isChoice ? "    [ -n \"$arg1\" ] || arg1=$(pick1 \"$(value search)\" id)" : "    [ -n \"$arg1\" ] || arg1=$(value search)"
        }
        var lines = ["    words=$(value search)", "    set -f", "    set -- $words", "    set +f"]
        for (number, argument) in numbered {
            let word = number == numbered.count ? "$*" : "$1"
            let value = argument.isChoice ? "$(pick\(number) \"\(word)\" id)" : "\"\(word)\""
            lines.append("    [ -n \"$arg\(number)\" ] || [ $# -eq 0 ] || arg\(number)=\(value)")
            if number < numbered.count { lines.append("    [ $# -eq 0 ] || shift") }
        }
        return lines.joined(separator: "\n")
    }

    static func label(_ number: Int, _ argument: RaycastArgument) -> String {
        argument.placeholder.isEmpty ? "Argument \(number)" : argument.placeholder
    }

    static func fields(_ numbered: [(number: Int, argument: RaycastArgument)], title: String, confirms: Bool, closes: Bool, again: Bool) -> String {
        let hints = numbered.isEmpty && !again
        let grid = (hints ? ["hint"] : []) + numbered.map { "arg\($0.number)" }
        var lines = ["fields() {", "  printf 'search=off\\n" + grid.map { "grid=\($0)\\n" }.joined() + "'"]
        lines.append("  [ \"$1\" != output ] || printf 'grid=output\\ngrid=output\\ngrid=output\\n'")
        if !again { lines.append("  printf 'grid=run\\n'") }
        if !confirms { lines.append("  [ -z \"$slash\" ] || printf 'slash=run\\n'") }
        if hints { lines += ["  printf '\\ntext=hint\\n'", "  openspot_kv title \(RaycastSpot.quoted("Press Return to run \(title)"))"] }
        for (number, argument) in numbered {
            let label = RaycastSpot.quoted(label(number, argument))
            if argument.isChoice {
                lines += ["  printf '\\nchoice=arg\(number)\\n'", "  openspot_kv title \(label)", "  openspot_kv value \"${arg\(number):-1}\""]
                for (index, option) in argument.options.enumerated() {
                    lines += ["  printf '\\noption=\(index + 1)\\n'", "  openspot_kv title \(RaycastSpot.quoted(option.title))"]
                }
            } else {
                lines += ["  printf '\\nfield=arg\(number)\\n'", "  openspot_kv title \(label)", "  openspot_kv placeholder \(label)", "  printf 'grow=false\\n'", "  openspot_kv value \"$arg\(number)\""]
            }
        }
        lines.append("  printf '\\nbutton=run\\ntitle=\(again ? "Run Again" : "Run")\\n\(again ? "" : "look=strong\\n")shortcut=\(again ? "cmd+r" : "return")\\nscope=spot\\n'")
        if confirms { lines.append("  printf 'confirm=Press again to run\\n'") }
        if closes { lines.append("  printf 'close=true\\n'") }
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    static func pick(_ number: Int, _ argument: RaycastArgument) -> String {
        var lines = ["pick\(number)() {", "  case \"$(printf '%s' \"$1\" | tr '[:upper:]' '[:lower:]')\" in"]
        for (index, option) in argument.options.enumerated() {
            let names = Set([String(index + 1), option.title.lowercased(), option.value.lowercased()]).sorted().map(RaycastSpot.quoted).joined(separator: "|")
            lines.append("    \(names)) [ \"$2\" = id ] && echo \(index + 1) || printf '%s' \(RaycastSpot.quoted(option.value)) ;;")
        }
        lines += ["  esac", "}"]
        return lines.joined(separator: "\n")
    }
}
