import Foundation

@objc protocol PowerService {
    func holdLidClosed(reply: @escaping @Sendable (String?) -> Void)
    func sample(reply: @escaping @Sendable (Data?, String?) -> Void)
}
