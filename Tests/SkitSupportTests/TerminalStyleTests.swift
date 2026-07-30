import SkitSupport
import XCTest

final class TerminalStyleTests: XCTestCase {
  func testEnablingTerminalSignatures() {
    for environment in [
      ["TERM": "xterm-256color"],
      ["TERM": "xterm", "COLORTERM": "truecolor"],
      ["TERM": "xterm", "COLORTERM": "24bit"],
    ] {
      XCTAssertTrue(
        TerminalStyle(
          isEnabled: TerminalStyle.detect(
            environment: environment,
            hasNoColor: false,
            isTerminal: true
          ).isEnabled
        ).isEnabled
      )
    }
  }

  func testColorSuppressors() {
    XCTAssertFalse(
      TerminalStyle.detect(
        environment: ["TERM": "xterm-256color"],
        hasNoColor: true,
        isTerminal: true
      ).isEnabled
    )
    XCTAssertFalse(
      TerminalStyle.detect(
        environment: ["TERM": "dumb", "COLORTERM": "truecolor"],
        hasNoColor: false,
        isTerminal: true
      ).isEnabled
    )
    XCTAssertFalse(
      TerminalStyle.detect(
        environment: ["TERM": "xterm-256color"],
        hasNoColor: false,
        isTerminal: false
      ).isEnabled
    )
    XCTAssertFalse(
      TerminalStyle.detect(
        environment: ["TERM": "xterm"],
        hasNoColor: false,
        isTerminal: true
      ).isEnabled
    )
  }

  func testExactRendering() {
    XCTAssertEqual(
      TerminalStyle(isEnabled: true).paint("38;5;15", "tree"),
      "\u{1B}[38;5;15mtree\u{1B}[0m"
    )
    XCTAssertEqual(TerminalStyle(isEnabled: false).paint("38;5;15", "tree"), "tree")
  }
}
