import Foundation

protocol PrintedRecord: Encodable {
    var blocks: [[(String, String?)]] { get }
}
