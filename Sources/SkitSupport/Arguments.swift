/// A failure to decode a process argument as strict UTF-8.
public struct ArgumentDecodingError: Error, Equatable {
  /// The zero-based argument index that could not be decoded.
  public let index: Int

  /// Creates an argument-decoding failure.
  public init(index: Int) {
    self.index = index
  }
}

/// Decodes raw process arguments without applying lossy Unicode conversion.
public enum RawArguments {
  /// Decodes `argc` and `argv` as strict UTF-8 strings.
  public static func decode(
    count: Int32,
    values: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>
  ) throws -> [String] {
    try (0..<Int(count)).map { index in
      guard let value = values[index], let decoded = String(validatingCString: value) else {
        throw ArgumentDecodingError(index: index)
      }
      return decoded
    }
  }

  /// Decodes one byte sequence as strict UTF-8 for deterministic tests.
  public static func decode(bytes: [UInt8], index: Int = 0) throws -> String {
    guard let decoded = String(bytes: bytes, encoding: .utf8) else {
      throw ArgumentDecodingError(index: index)
    }
    return decoded
  }
}
