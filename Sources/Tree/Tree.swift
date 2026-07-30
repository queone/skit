import Foundation
import SkitSupport

/// A tree command failure with its process exit code.
public struct TreeError: Error {
  /// User-facing diagnostic.
  public let message: String

  /// Process exit code.
  public let exitCode: Int32
}

enum TreeCommand: Equatable {
  case help
  case version
  case render(root: String, fullPath: Bool)
}

struct TreeNode: Equatable {
  let name: String
  let isDirectory: Bool
}

protocol TreeDirectorySource {
  func entries(at path: String) throws -> [TreeNode]
}

struct TreeFilesystem: TreeDirectorySource {
  func entries(at path: String) throws -> [TreeNode] {
    let manager = FileManager.default
    var isDirectory = ObjCBool(false)
    guard manager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
      throw CocoaError(.fileReadNoSuchFile)
    }
    return try manager.contentsOfDirectory(atPath: path).map { name in
      let child = lexicalJoin(path, name)
      let isSymbolicLink = (try? manager.destinationOfSymbolicLink(atPath: child)) != nil
      let childIsDirectory: Bool
      if isSymbolicLink {
        childIsDirectory = false
      } else {
        let attributes = try manager.attributesOfItem(atPath: child)
        childIsDirectory = attributes[.type] as? FileAttributeType == .typeDirectory
      }
      return TreeNode(
        name: name,
        isDirectory: childIsDirectory
      )
    }
  }
}

struct TreeOutput: Equatable {
  let stdout: String
  let stderr: String
}

private struct RenderedTreeEntry {
  let prefix: String
  let isLast: Bool
  let name: String
  let path: String
  let isDirectory: Bool
  let scalarWidth: Int
}

/// Parses a tree argument sequence.
func parseTree(arguments: [String]) throws -> TreeCommand {
  var root = "."
  var fullPath = false
  var parsesOptions = true

  for argument in arguments {
    if parsesOptions {
      switch argument {
      case "-h", "-?", "--help":
        return .help
      case "-v", "--version":
        return .version
      case "-f", "--full-path":
        fullPath = true
        continue
      case "--":
        parsesOptions = false
        continue
      default:
        if argument.hasPrefix("-"), argument != "-" {
          throw TreeError(
            message:
              "parse option \(argument.debugDescription): unsupported option; use --help for usage",
            exitCode: 2
          )
        }
      }
    }
    root = argument
  }
  return .render(root: root, fullPath: fullPath)
}

/// Cleans a path lexically without accessing the filesystem.
func cleanTreePath(_ path: String) -> String {
  let absolute = path.hasPrefix("/")
  var components: [Substring] = []
  for component in path.split(separator: "/", omittingEmptySubsequences: true) {
    switch component {
    case ".":
      continue
    case "..":
      if let last = components.last, last != ".." {
        components.removeLast()
      } else if !absolute {
        components.append(component)
      }
    default:
      components.append(component)
    }
  }
  let joined = components.joined(separator: "/")
  if absolute {
    return joined.isEmpty ? "/" : "/\(joined)"
  }
  return joined.isEmpty ? "." : joined
}

func lexicalJoin(_ root: String, _ name: String) -> String {
  cleanTreePath(root == "/" ? "/\(name)" : "\(root)/\(name)")
}

private func treeHelp(style: TerminalStyle) -> String {
  let name = style.paint("38;5;15", "tree")
  let usage = style.paint("38;5;15", "Usage")
  let options = style.paint("38;5;15", "Options")
  let examples = style.paint("38;5;15", "Examples")
  return """
    \(name) v\(SkitVersion.current)
    Directory tree printer — https://github.com/queone/skit
    \(usage)
      \(name) [options] [directory]

      Options can appear before or after directory operands. The last directory
      operand is used. Use -- before a directory whose name begins with a dash.

    \(options)
      -f, --full-path  Show each file's path joined to the directory operand
      -v, --version    Print version and exit
      -h, -?, --help   Show this help message and exit
      --               End option parsing

    \(examples)
      \(name)
      \(name) -f /path/to/directory
      \(name) /path/to/directory --full-path
      \(name) -- -directory

    """
}

private func utf8Precedes(_ left: String, _ right: String) -> Bool {
  Array(left.utf8).lexicographicallyPrecedes(Array(right.utf8))
}

private func gatherTree(
  source: TreeDirectorySource,
  directory: String,
  prefix: String,
  isRoot: Bool,
  entries: inout [RenderedTreeEntry],
  warnings: inout [String]
) throws {
  let nodes: [TreeNode]
  do {
    nodes = try source.entries(at: directory).sorted {
      utf8Precedes($0.name, $1.name)
    }
  } catch {
    if isRoot {
      throw TreeError(
        message:
          "read directory \(directory.debugDescription): \(error); verify the path exists and is readable",
        exitCode: 1
      )
    }
    warnings.append(
      "skip unreadable directory \(directory.debugDescription): \(error); grant access to include its contents"
    )
    return
  }

  for (index, node) in nodes.enumerated() {
    let isLast = index + 1 == nodes.count
    let mark = isLast ? "└── " : "├── "
    let path = lexicalJoin(directory, node.name)
    let rawLine = "\(prefix)\(mark)\(node.name)"
    entries.append(
      RenderedTreeEntry(
        prefix: prefix,
        isLast: isLast,
        name: node.name,
        path: path,
        isDirectory: node.isDirectory,
        scalarWidth: rawLine.unicodeScalars.count
      )
    )
    if node.isDirectory {
      try gatherTree(
        source: source,
        directory: path,
        prefix: prefix + (isLast ? "    " : "│   "),
        isRoot: false,
        entries: &entries,
        warnings: &warnings
      )
    }
  }
}

func renderTree(
  root: String,
  fullPath: Bool,
  source: TreeDirectorySource,
  style: TerminalStyle
) throws -> TreeOutput {
  var entries: [RenderedTreeEntry] = []
  var warnings: [String] = []
  try gatherTree(
    source: source,
    directory: root,
    prefix: "",
    isRoot: true,
    entries: &entries,
    warnings: &warnings
  )
  let maximumWidth = entries.map(\.scalarWidth).max() ?? 0
  var stdout = ""
  for entry in entries {
    let mark = entry.isLast ? "└── " : "├── "
    stdout += entry.prefix
    stdout += mark
    stdout += style.paint(entry.isDirectory ? "38;5;21" : "38;5;46", entry.name)
    if fullPath, !entry.isDirectory {
      stdout += String(repeating: " ", count: maximumWidth + 4 - entry.scalarWidth)
      stdout += style.paint("38;5;51", entry.path)
    }
    stdout += "\n"
  }
  let stderr = warnings.isEmpty ? "" : warnings.joined(separator: "\n") + "\n"
  return TreeOutput(stdout: stdout, stderr: stderr)
}

/// Runs tree and returns its buffered output.
public func runTree(
  arguments: [String],
  style: TerminalStyle = .detect()
) throws -> (stdout: Data, stderr: Data) {
  switch try parseTree(arguments: arguments) {
  case .help:
    return (Data(treeHelp(style: style).utf8), Data())
  case .version:
    return (Data("tree v\(SkitVersion.current)\n".utf8), Data())
  case .render(let root, let fullPath):
    let result = try renderTree(
      root: root,
      fullPath: fullPath,
      source: TreeFilesystem(),
      style: style
    )
    return (Data(result.stdout.utf8), Data(result.stderr.utf8))
  }
}

/// Executes tree through injectable output writers.
public func executeTree(
  arguments: [String],
  style: TerminalStyle = .detect(),
  stdout: (Data) throws -> Void,
  stderr: (Data) throws -> Void
) -> Int32 {
  do {
    let output = try runTree(arguments: arguments, style: style)
    do {
      try stdout(output.stdout)
    } catch {
      try? stderr(
        Data(
          "write command output: \(error); verify standard output is writable and retry\n"
            .utf8
        )
      )
      return 1
    }
    if !output.stderr.isEmpty {
      do {
        try stderr(output.stderr)
      } catch {
        return 1
      }
    }
    return 0
  } catch let error as TreeError {
    do {
      try stderr(Data("\(error.message)\n".utf8))
      return error.exitCode
    } catch {
      return 1
    }
  } catch {
    do {
      try stderr(
        Data("run tree: \(error); verify the directory is readable and retry\n".utf8)
      )
      return 1
    } catch {
      return 1
    }
  }
}
