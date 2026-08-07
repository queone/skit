import Foundation
import SkitSupport
import XCTest

@testable import Dos2Unix

final class Dos2UnixTests: XCTestCase {
  private func fixture(_ label: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("skit-dos2unix-\(label)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    addTeardownBlock {
      try? FileManager.default.removeItem(at: url)
    }
    return url
  }

  func testArgumentFormsAndTerminalFlags() throws {
    XCTAssertEqual(try parseDos2Unix(arguments: ["file"]), .preview("file"))
    XCTAssertEqual(try parseDos2Unix(arguments: ["-f", "file"]), .convert("file"))
    XCTAssertEqual(try parseDos2Unix(arguments: ["file", "--force"]), .convert("file"))
    XCTAssertEqual(try parseDos2Unix(arguments: ["--", "-file"]), .preview("-file"))
    XCTAssertEqual(try parseDos2Unix(arguments: ["file", "--help", "--bad"]), .help)
    XCTAssertThrowsError(try parseDos2Unix(arguments: []))
    XCTAssertThrowsError(try parseDos2Unix(arguments: ["first", "second"]))
    XCTAssertThrowsError(try parseDos2Unix(arguments: ["--bad"]))
  }

  func testPreviewAndConversionPreserveArbitraryBytes() {
    let input = Data([97, 13, 10, 13, 10, 98, 10, 99, 13, 255])
    XCTAssertEqual(
      renderDos2UnixPreview(input, style: TerminalStyle(isEnabled: false)),
      Data([97] + Array("\\r\\n\n\\r\\n\n".utf8) + [98, 10, 99, 13, 255])
    )
    XCTAssertEqual(
      convertDos2UnixBytes(input),
      Data([97, 10, 10, 98, 10, 99, 13, 255])
    )
    XCTAssertEqual(convertDos2UnixBytes(Data()), Data())
    XCTAssertEqual(
      renderDos2UnixPreview(
        Data([13, 10]),
        style: TerminalStyle(isEnabled: true)
      ),
      Data("\u{1B}[34m\\r\\n\u{1B}[0m\n".utf8)
    )
  }

  func testPreviewDoesNotModifyAndForceConvertsWithoutOutput() throws {
    let directory = try fixture("files")
    let file = directory.appendingPathComponent("mixed")
    let input = Data([97, 13, 10, 255])
    try input.write(to: file)

    let preview = try runDos2Unix(
      arguments: [file.path],
      style: TerminalStyle(isEnabled: false)
    )
    XCTAssertEqual(preview, Data([97] + Array("\\r\\n\n".utf8) + [255]))
    XCTAssertEqual(try Data(contentsOf: file), input)

    XCTAssertEqual(try runDos2Unix(arguments: ["-f", file.path]), Data())
    XCTAssertEqual(try Data(contentsOf: file), Data([97, 10, 255]))
  }

  func testConversionPreservesLinksInodeAndMode() throws {
    #if os(macOS) || os(Linux)
      let directory = try fixture("metadata")
      let target = directory.appendingPathComponent("target")
      let hardLink = directory.appendingPathComponent("hard")
      let symbolicLink = directory.appendingPathComponent("symbolic")
      try Data("a\r\n".utf8).write(to: target)
      try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
      try FileManager.default.linkItem(at: target, to: hardLink)
      try FileManager.default.createSymbolicLink(at: symbolicLink, withDestinationURL: target)
      let before = try FileManager.default.attributesOfItem(atPath: target.path)

      _ = try runDos2Unix(arguments: [symbolicLink.path, "--force"])

      let after = try FileManager.default.attributesOfItem(atPath: target.path)
      XCTAssertEqual(before[.systemFileNumber] as? NSNumber, after[.systemFileNumber] as? NSNumber)
      XCTAssertEqual(after[.posixPermissions] as? NSNumber, NSNumber(value: 0o640))
      XCTAssertEqual(try Data(contentsOf: hardLink), Data("a\n".utf8))
      XCTAssertEqual(
        try FileManager.default.destinationOfSymbolicLink(atPath: symbolicLink.path),
        target.path
      )
    #endif
  }

  func testHelpVersionErrorsAndWriteFailures() throws {
    let help = try runDos2Unix(
      arguments: ["--help"],
      style: TerminalStyle(isEnabled: false)
    )
    XCTAssertTrue(String(decoding: help, as: UTF8.self).contains("dos2unix [options] [--] FILE"))
    let coloredHelp = try runDos2Unix(
      arguments: ["--help"],
      style: TerminalStyle(isEnabled: true)
    )
    XCTAssertTrue(
      String(decoding: coloredHelp, as: UTF8.self)
        .contains("\u{1B}[38;5;15mdos2unix\u{1B}[0m")
    )
    XCTAssertEqual(
      try runDos2Unix(arguments: ["--version"]),
      Data("dos2unix v0.1.4\n".utf8)
    )

    var standardError = Data()
    let code = executeDos2Unix(
      arguments: ["--help"],
      style: TerminalStyle(isEnabled: false),
      stdout: { _ in throw CocoaError(.fileWriteUnknown) },
      stderr: { standardError.append($0) }
    )
    XCTAssertEqual(code, 1)
    XCTAssertTrue(String(decoding: standardError, as: UTF8.self).contains("writable and retry"))

    var attempts = 0
    let missingCode = executeDos2Unix(
      arguments: [],
      stdout: { _ in XCTFail("unexpected stdout") },
      stderr: { _ in
        attempts += 1
        throw CocoaError(.fileWriteUnknown)
      }
    )
    XCTAssertEqual(missingCode, 1)
    XCTAssertEqual(attempts, 1)
  }

  func testMissingNonregularAndDanglingOperandsFail() throws {
    let directory = try fixture("invalid")
    let missing = directory.appendingPathComponent("missing")
    XCTAssertThrowsError(try runDos2Unix(arguments: [missing.path]))
    XCTAssertThrowsError(try runDos2Unix(arguments: [directory.path]))

    #if os(macOS) || os(Linux)
      let dangling = directory.appendingPathComponent("dangling")
      try FileManager.default.createSymbolicLink(
        at: dangling,
        withDestinationURL: missing
      )
      XCTAssertThrowsError(try runDos2Unix(arguments: [dangling.path]))
    #endif
  }
}
