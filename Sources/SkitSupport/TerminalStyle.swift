import Foundation

#if canImport(Darwin)
  import Darwin
#else
  import Glibc
#endif

/// Terminal-aware ANSI rendering shared by skit executables.
public struct TerminalStyle: Sendable {
  /// Whether ANSI rendering is active.
  public let isEnabled: Bool

  /// Creates a terminal style with an explicit state.
  public init(isEnabled: Bool) {
    self.isEnabled = isEnabled
  }

  /// Detects the pinned color policy from environment and terminal state.
  public static func detect(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    hasNoColor: Bool? = nil,
    isTerminal: Bool = isatty(STDOUT_FILENO) == 1
  ) -> TerminalStyle {
    let noColorExists = hasNoColor ?? ProcessInfo.processInfo.environment.keys.contains("NO_COLOR")
    let term = environment["TERM"] ?? ""
    let colorTerm = environment["COLORTERM"] ?? ""
    let supportsColor =
      term.contains("256color") || colorTerm == "truecolor" || colorTerm == "24bit"
    return TerminalStyle(
      isEnabled: isTerminal && supportsColor && !noColorExists && term != "dumb"
    )
  }

  /// Wraps text in an ANSI color when rendering is enabled.
  public func paint(_ code: String, _ text: String) -> String {
    guard isEnabled else {
      return text
    }
    return "\u{1B}[\(code)m\(text)\u{1B}[0m"
  }
}
