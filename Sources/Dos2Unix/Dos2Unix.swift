import Foundation
import SkitSupport

/// A command failure with its process exit code.
public struct Dos2UnixError: Error {
  /// User-facing diagnostic.
  public let message: String

  /// Process exit code.
  public let exitCode: Int32
}

enum Dos2UnixCommand: Equatable {
  case help
  case version
  case preview(String)
  case convert(String)
}

struct Dos2UnixFileFailure: Error {
  let operation: String
  let path: String
  let underlying: Error
  let afterTruncate: Bool
}

/// Parses a dos2unix argument sequence.
func parseDos2Unix(arguments: [String]) throws -> Dos2UnixCommand {
  var path: String?
  var force = false
  var parsesOptions = true

  for argument in arguments {
    if parsesOptions {
      switch argument {
      case "-h", "-?", "--help":
        return .help
      case "-v", "--version":
        return .version
      case "-f", "--force":
        force = true
        continue
      case "--":
        parsesOptions = false
        continue
      default:
        if argument.hasPrefix("-") {
          throw Dos2UnixError(
            message:
              "parse option \(argument.debugDescription): unsupported option; use --help for usage",
            exitCode: 2
          )
        }
      }
    }

    guard path == nil else {
      throw Dos2UnixError(
        message:
          "parse operand \(argument.debugDescription): expected exactly one FILE; use --help for usage",
        exitCode: 2
      )
    }
    path = argument
  }

  guard let path else {
    throw Dos2UnixError(
      message: "parse arguments: missing FILE operand; use --help for usage",
      exitCode: 2
    )
  }
  return force ? .convert(path) : .preview(path)
}

/// Replaces CRLF pairs with visible marker bytes and a line feed.
func renderDos2UnixPreview(_ input: Data, style: TerminalStyle) -> Data {
  let bytes = [UInt8](input)
  let marker = Array((style.isEnabled ? "\u{1B}[34m\\r\\n\u{1B}[0m" : "\\r\\n").utf8)
  var output: [UInt8] = []
  output.reserveCapacity(bytes.count)
  var index = 0
  while index < bytes.count {
    if index + 1 < bytes.count, bytes[index] == 13, bytes[index + 1] == 10 {
      output.append(contentsOf: marker)
      output.append(10)
      index += 2
    } else {
      output.append(bytes[index])
      index += 1
    }
  }
  return Data(output)
}

/// Replaces CRLF pairs with line feeds without decoding file content.
func convertDos2UnixBytes(_ input: Data) -> Data {
  let bytes = [UInt8](input)
  var output: [UInt8] = []
  output.reserveCapacity(bytes.count)
  var index = 0
  while index < bytes.count {
    if index + 1 < bytes.count, bytes[index] == 13, bytes[index + 1] == 10 {
      output.append(10)
      index += 2
    } else {
      output.append(bytes[index])
      index += 1
    }
  }
  return Data(output)
}

private func validateRegularFile(path: String) throws {
  do {
    let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
    let attributes = try FileManager.default.attributesOfItem(atPath: resolved)
    guard attributes[.type] as? FileAttributeType == .typeRegular else {
      throw CocoaError(.fileReadUnsupportedScheme)
    }
  } catch {
    throw Dos2UnixFileFailure(
      operation: "inspect",
      path: path,
      underlying: error,
      afterTruncate: false
    )
  }
}

private func readRegularFile(path: String) throws -> Data {
  try validateRegularFile(path: path)
  do {
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
    defer {
      try? handle.close()
    }
    return try handle.readToEnd() ?? Data()
  } catch {
    throw Dos2UnixFileFailure(
      operation: "read",
      path: path,
      underlying: error,
      afterTruncate: false
    )
  }
}

private func convertRegularFile(path: String) throws {
  try validateRegularFile(path: path)
  let handle: FileHandle
  do {
    handle = try FileHandle(forUpdating: URL(fileURLWithPath: path))
  } catch {
    throw Dos2UnixFileFailure(
      operation: "open for conversion",
      path: path,
      underlying: error,
      afterTruncate: false
    )
  }
  defer {
    try? handle.close()
  }

  let input: Data
  do {
    input = try handle.readToEnd() ?? Data()
    try handle.seek(toOffset: 0)
  } catch {
    throw Dos2UnixFileFailure(
      operation: "read",
      path: path,
      underlying: error,
      afterTruncate: false
    )
  }

  do {
    try handle.truncate(atOffset: 0)
  } catch {
    throw Dos2UnixFileFailure(
      operation: "truncate",
      path: path,
      underlying: error,
      afterTruncate: false
    )
  }
  do {
    try handle.write(contentsOf: convertDos2UnixBytes(input))
    try handle.synchronize()
  } catch {
    throw Dos2UnixFileFailure(
      operation: "write",
      path: path,
      underlying: error,
      afterTruncate: true
    )
  }
}

private func dos2unixHelp(style: TerminalStyle) -> Data {
  let name = style.paint("38;5;15", "dos2unix")
  return Data(
    """
    \(name) v\(SkitVersion.current)
    Preview or convert CRLF line endings — https://github.com/queone/skit
    Usage
      \(name) [options] [--] FILE

      Preview FILE and display each CRLF pair as visible \\r\\n text.
      Use -- before a FILE whose name begins with a dash.

    Options
      -f, --force    Convert CRLF pairs to LF in place
      -v, --version  Print version and exit
      -h, -?, --help Show this help message and exit
      --             End option parsing

    """.utf8
  )
}

/// Runs dos2unix and returns successful standard-output bytes.
public func runDos2Unix(
  arguments: [String],
  style: TerminalStyle = .detect()
) throws -> Data {
  do {
    switch try parseDos2Unix(arguments: arguments) {
    case .help:
      return dos2unixHelp(style: style)
    case .version:
      return Data("dos2unix v\(SkitVersion.current)\n".utf8)
    case .preview(let path):
      return renderDos2UnixPreview(try readRegularFile(path: path), style: style)
    case .convert(let path):
      try convertRegularFile(path: path)
      return Data()
    }
  } catch let error as Dos2UnixError {
    throw error
  } catch let failure as Dos2UnixFileFailure {
    let recovery =
      failure.afterTruncate
      ? "the file may be partially written; restore it from a backup or source control before retrying"
      : "verify the operand names a readable regular file and retry"
    throw Dos2UnixError(
      message:
        "\(failure.operation) file \(failure.path.debugDescription): \(failure.underlying); \(recovery)",
      exitCode: 1
    )
  } catch {
    throw Dos2UnixError(
      message: "run dos2unix: \(error); verify the operand and retry",
      exitCode: 1
    )
  }
}

/// Executes dos2unix through injectable output writers.
public func executeDos2Unix(
  arguments: [String],
  style: TerminalStyle = .detect(),
  stdout: (Data) throws -> Void,
  stderr: (Data) throws -> Void
) -> Int32 {
  do {
    let output = try runDos2Unix(arguments: arguments, style: style)
    do {
      try stdout(output)
      return 0
    } catch {
      let diagnostic = Data(
        "write command output: \(error); verify standard output is writable and retry\n".utf8
      )
      try? stderr(diagnostic)
      return 1
    }
  } catch let error as Dos2UnixError {
    do {
      try stderr(Data("\(error.message)\n".utf8))
      return error.exitCode
    } catch {
      return 1
    }
  } catch {
    do {
      try stderr(Data("run dos2unix: \(error); retry after correcting the failure\n".utf8))
      return 1
    } catch {
      return 1
    }
  }
}
