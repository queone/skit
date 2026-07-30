import SkitSupport
import XCTest

final class ArgumentsTests: XCTestCase {
  func testStrictUTF8Decoding() throws {
    XCTAssertEqual(try RawArguments.decode(bytes: Array("βeta".utf8)), "βeta")
    XCTAssertThrowsError(try RawArguments.decode(bytes: [0x66, 0x80], index: 3)) { error in
      XCTAssertEqual(error as? ArgumentDecodingError, ArgumentDecodingError(index: 3))
    }
  }
}
