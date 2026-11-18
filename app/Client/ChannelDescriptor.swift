import Darwin

enum ChannelDescriptor {
    static let number: Int32 = 11

    private static let header = (MemoryLayout<cmsghdr>.size + 3) & ~3
    private static let space = header + MemoryLayout<Int32>.size

    static func isChannel(_ descriptor: Int32) -> Bool {
        var type: Int32 = 0
        var size = socklen_t(MemoryLayout<Int32>.size)
        guard getsockopt(descriptor, SOL_SOCKET, SO_TYPE, &type, &size) == 0, type == SOCK_DGRAM else { return false }
        var address = sockaddr_storage()
        var length = socklen_t(MemoryLayout<sockaddr_storage>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(descriptor, $0, &length) }
        }
        return named == 0 && address.ss_family == sa_family_t(AF_UNIX)
    }

    static func send(_ descriptor: Int32, over socket: Int32) -> Bool {
        var byte: UInt8 = 0
        var control = [UInt8](repeating: 0, count: space)
        control.withUnsafeMutableBytes { bytes in
            let head = bytes.baseAddress!.assumingMemoryBound(to: cmsghdr.self)
            head.pointee = cmsghdr(cmsg_len: socklen_t(space), cmsg_level: SOL_SOCKET, cmsg_type: SCM_RIGHTS)
            bytes.storeBytes(of: descriptor, toByteOffset: header, as: Int32.self)
        }
        return withUnsafeMutablePointer(to: &byte) { pointer in
            var vector = iovec(iov_base: pointer, iov_len: 1)
            return control.withUnsafeMutableBytes { bytes in
                withUnsafeMutablePointer(to: &vector) { vectors in
                    var message = msghdr(msg_name: nil, msg_namelen: 0, msg_iov: vectors, msg_iovlen: 1, msg_control: bytes.baseAddress, msg_controllen: socklen_t(space), msg_flags: 0)
                    return sendmsg(socket, &message, 0) == 1
                }
            }
        }
    }

    static func receive(from socket: Int32) -> Int32? {
        var byte: UInt8 = 0
        var control = [UInt8](repeating: 0, count: space)
        let (count, length) = withUnsafeMutablePointer(to: &byte) { pointer in
            var vector = iovec(iov_base: pointer, iov_len: 1)
            return control.withUnsafeMutableBytes { bytes in
                withUnsafeMutablePointer(to: &vector) { vectors in
                    var message = msghdr(msg_name: nil, msg_namelen: 0, msg_iov: vectors, msg_iovlen: 1, msg_control: bytes.baseAddress, msg_controllen: socklen_t(space), msg_flags: 0)
                    let count = recvmsg(socket, &message, 0)
                    return (count, Int(message.msg_controllen))
                }
            }
        }
        guard count >= 0 else { return nil }
        guard length >= space else { return -1 }
        return control.withUnsafeBytes { bytes in
            let head = bytes.load(as: cmsghdr.self)
            guard head.cmsg_level == SOL_SOCKET, head.cmsg_type == SCM_RIGHTS else { return -1 }
            return bytes.load(fromByteOffset: header, as: Int32.self)
        }
    }
}
