/// Who searches a list: Openspot over the rows it holds, or the script, which prints `search=script` to ask for it.
public enum ItemSearch: String, Sendable {
    case local
    case script
    /// No search: the panel shows no field over the rows, as for a list that is still empty of the person's things.
    case off
}
