import Foundation
import SkitSupport
import XCTest

@testable import Tree

private struct MemoryTree: TreeDirectorySource {
  let values: [String: Result<[TreeNode], Error>]

  func entries(at path: String) throws -> [TreeNode] {
    try values[path, default: .success([])].get()
  }
}

final class TreeTests: XCTestCase {
  func testArgumentsAndTerminalFlags() throws {
    XCTAssertEqual(try parseTree(arguments: []), .render(root: ".", fullPath: false))
    XCTAssertEqual(
      try parseTree(arguments: ["first", "-f", "second"]),
      .render(root: "second", fullPath: true)
    )
    XCTAssertEqual(
      try parseTree(arguments: ["-f", "--", "-first", "-last"]),
      .render(root: "-last", fullPath: true)
    )
    XCTAssertEqual(try parseTree(arguments: ["root", "--help", "--bad"]), .help)
    XCTAssertThrowsError(try parseTree(arguments: ["--bad", "--help"]))
  }

  func testSortedNestedRenderingAndDotfiles() throws {
    let source = MemoryTree(values: [
      ".": .success([
        TreeNode(name: "βeta", isDirectory: false),
        TreeNode(name: "nested", isDirectory: true),
        TreeNode(name: ".hidden", isDirectory: false),
        TreeNode(name: "alpha", isDirectory: false),
      ]),
      "nested": .success([TreeNode(name: "z", isDirectory: false)]),
    ])
    let output = try renderTree(
      root: ".",
      fullPath: false,
      source: source,
      style: TerminalStyle(isEnabled: false)
    )
    XCTAssertEqual(
      output.stdout,
      "├── .hidden\n├── alpha\n├── nested\n│   └── z\n└── βeta\n"
    )
    XCTAssertEqual(output.stderr, "")
  }

  func testUTF8ByteOrderingDistinguishesNormalization() throws {
    let source = MemoryTree(values: [
      ".": .success([
        TreeNode(name: "é", isDirectory: false),
        TreeNode(name: "e\u{301}", isDirectory: false),
      ])
    ])
    let output = try renderTree(
      root: ".",
      fullPath: false,
      source: source,
      style: TerminalStyle(isEnabled: false)
    )
    XCTAssertEqual(output.stdout, "├── e\u{301}\n└── é\n")
  }

  func testLexicalCleaningAndScalarAlignment() throws {
    for (input, expected) in [
      ("./a//b/../file/", "a/file"),
      ("../../a", "../../a"),
      ("/../../a", "/a"),
      ("a/..", "."),
      ("/a/..", "/"),
    ] {
      XCTAssertEqual(cleanTreePath(input), expected)
    }
    let source = MemoryTree(values: [
      ".": .success([
        TreeNode(name: "a", isDirectory: false),
        TreeNode(name: "界", isDirectory: false),
      ])
    ])
    let output = try renderTree(
      root: ".",
      fullPath: true,
      source: source,
      style: TerminalStyle(isEnabled: false)
    )
    XCTAssertEqual(output.stdout, "├── a    a\n└── 界    界\n")
  }

  func testDescendantFailureWarnsAndFatalRootBuffersOutput() throws {
    let denied = CocoaError(.fileReadNoPermission)
    let source = MemoryTree(values: [
      ".": .success([
        TreeNode(name: "before", isDirectory: false),
        TreeNode(name: "nested", isDirectory: true),
        TreeNode(name: "z", isDirectory: false),
      ]),
      "nested": .failure(denied),
    ])
    let output = try renderTree(
      root: ".",
      fullPath: false,
      source: source,
      style: TerminalStyle(isEnabled: false)
    )
    XCTAssertEqual(output.stdout, "├── before\n├── nested\n└── z\n")
    XCTAssertTrue(output.stderr.contains("skip unreadable directory"))

    XCTAssertThrowsError(
      try renderTree(
        root: "missing",
        fullPath: false,
        source: MemoryTree(values: ["missing": .failure(denied)]),
        style: TerminalStyle(isEnabled: false)
      )
    )
  }

  func testExactColorsHelpVersionAndWriteFailures() throws {
    let source = MemoryTree(values: [
      ".": .success([
        TreeNode(name: "dir", isDirectory: true),
        TreeNode(name: "file", isDirectory: false),
      ]),
      "dir": .success([]),
    ])
    let output = try renderTree(
      root: ".",
      fullPath: true,
      source: source,
      style: TerminalStyle(isEnabled: true)
    )
    XCTAssertTrue(output.stdout.contains("\u{1B}[38;5;21mdir\u{1B}[0m"))
    XCTAssertTrue(output.stdout.contains("\u{1B}[38;5;46mfile\u{1B}[0m"))
    XCTAssertTrue(output.stdout.contains("\u{1B}[38;5;51mfile\u{1B}[0m"))

    let help = try runTree(arguments: ["--help"], style: TerminalStyle(isEnabled: false))
    XCTAssertTrue(String(decoding: help.stdout, as: UTF8.self).contains("-f, --full-path"))
    let coloredHelp = try runTree(
      arguments: ["--help"],
      style: TerminalStyle(isEnabled: true)
    )
    let coloredText = String(decoding: coloredHelp.stdout, as: UTF8.self)
    XCTAssertTrue(coloredText.contains("\u{1B}[38;5;15mtree\u{1B}[0m"))
    XCTAssertTrue(coloredText.contains("\u{1B}[38;5;15mUsage\u{1B}[0m"))
    XCTAssertEqual(try runTree(arguments: ["--version"]).stdout, Data("tree v0.1.5\n".utf8))

    var standardError = Data()
    let code = executeTree(
      arguments: ["--help"],
      style: TerminalStyle(isEnabled: false),
      stdout: { _ in throw CocoaError(.fileWriteUnknown) },
      stderr: { standardError.append($0) }
    )
    XCTAssertEqual(code, 1)
    XCTAssertTrue(String(decoding: standardError, as: UTF8.self).contains("writable and retry"))

    var attempts = 0
    let errorCode = executeTree(
      arguments: ["--bad"],
      stdout: { _ in XCTFail("unexpected stdout") },
      stderr: { _ in
        attempts += 1
        throw CocoaError(.fileWriteUnknown)
      }
    )
    XCTAssertEqual(errorCode, 1)
    XCTAssertEqual(attempts, 1)
  }

  func testFilesystemRootAndDescendantSymlinks() throws {
    #if os(macOS) || os(Linux)
      let manager = FileManager.default
      let fixture = manager.temporaryDirectory
        .appendingPathComponent("skit-tree-links-\(UUID().uuidString)")
      let root = fixture.appendingPathComponent("root")
      let rootLink = fixture.appendingPathComponent("root-link")
      let childDirectory = root.appendingPathComponent("directory")
      let childLink = root.appendingPathComponent("directory-link")
      let brokenLink = root.appendingPathComponent("broken")
      try manager.createDirectory(at: childDirectory, withIntermediateDirectories: true)
      try Data().write(to: childDirectory.appendingPathComponent("inside"))
      try manager.createSymbolicLink(at: rootLink, withDestinationURL: root)
      try manager.createSymbolicLink(at: childLink, withDestinationURL: childDirectory)
      try manager.createSymbolicLink(
        at: brokenLink,
        withDestinationURL: root.appendingPathComponent("missing")
      )
      addTeardownBlock {
        try? manager.removeItem(at: fixture)
      }

      let output = try runTree(
        arguments: [rootLink.path],
        style: TerminalStyle(isEnabled: false)
      )
      let text = String(decoding: output.stdout, as: UTF8.self)
      XCTAssertTrue(text.contains("broken"))
      XCTAssertTrue(text.contains("directory-link"))
      XCTAssertEqual(text.components(separatedBy: "inside").count - 1, 1)

      let file = fixture.appendingPathComponent("file")
      try Data().write(to: file)
      XCTAssertThrowsError(try runTree(arguments: [file.path]))
    #endif
  }
}
