import XCTest
@testable import OpenspotCore

final class ScryptTests: XCTestCase {
    private func hex(_ data: Data?) -> String {
        (data ?? Data()).map { String(format: "%02x", $0) }.joined()
    }

    func testTheKeyMatchesTheFirstVectorOfRFC7914() {
        let key = Scrypt.key(password: Data(), salt: Data(), cost: 16, blockSize: 1, parallel: 1, length: 64)

        XCTAssertEqual(hex(key), "77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906")
    }

    func testTheKeyMatchesTheSecondVectorOfRFC7914() {
        let key = Scrypt.key(password: Data("password".utf8), salt: Data("NaCl".utf8), cost: 1024, blockSize: 8, parallel: 16, length: 64)

        XCTAssertEqual(hex(key), "fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b3731622eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640")
    }

    func testACostThatIsNotAPowerOfTwoGivesNoKey() {
        XCTAssertNil(Scrypt.key(password: Data(), salt: Data(), cost: 1000, blockSize: 8, parallel: 1, length: 32))
    }
}
