import Foundation
import SkitSupport

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

let exitCode: Int32
do {
  let decoded = try RawArguments.decode(count: CommandLine.argc, values: CommandLine.unsafeArgv)
  exitCode = executeTree(
    arguments: Array(decoded.dropFirst()),
    stdout: { try FileHandle.standardOutput.write(contentsOf: $0) },
    stderr: { try FileHandle.standardError.write(contentsOf: $0) }
  )
} catch let error as ArgumentDecodingError {
  let diagnostic = Data(
    "decode argument \(error.index): argument is not valid UTF-8; rename the operand and retry\n"
      .utf8
  )
  do {
    try FileHandle.standardError.write(contentsOf: diagnostic)
  } catch {}
  exitCode = 1
} catch {
  let diagnostic = Data("decode arguments: \(error); correct the arguments and retry\n".utf8)
  do {
    try FileHandle.standardError.write(contentsOf: diagnostic)
  } catch {}
  exitCode = 1
}

exit(exitCode)
