/// Who searches a list: Openspot over the rows it holds, or the script, whose header has `on=sheet.text`.
public enum ItemSearch: String, Sendable {
    case local
    case script
}
