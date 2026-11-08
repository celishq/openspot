/// Who searches a list: Openspot over the rows it holds, or the script, which prints `search=script` to ask for it.
public enum ItemSearch: String, Sendable {
    case local
    case script
}
