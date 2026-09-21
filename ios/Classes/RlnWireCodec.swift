import Foundation

// Owns JSON wire encoding separately from native operation/lifecycle dispatch.
enum RlnWireCodec {
  static func encode(_ value: Any?) throws -> RlnWireResponse {
    let jsonValue = try jsonCompatibleValue(value)
    let data = try JSONSerialization.data(withJSONObject: jsonValue, options: [.sortedKeys])
    guard let json = String(data: data, encoding: .utf8) else {
      throw PigeonError(
        code: "nativeProtocol",
        message: "Native response JSON was not valid UTF-8.",
        details: nil
      )
    }
    return RlnWireResponse(json: json)
  }

  private static func jsonCompatibleValue(_ value: Any?) throws -> Any {
    guard let value else {
      return NSNull()
    }
    switch value {
    case is NSNull:
      return NSNull()
    case let value as [AnyHashable?: Any?]:
      var object = [String: Any]()
      for (key, entryValue) in value {
        let keyString = key.map { String(describing: $0) } ?? "null"
        object[keyString] = try jsonCompatibleValue(entryValue ?? nil)
      }
      return object
    case let value as [String: Any?]:
      var object = [String: Any]()
      for (key, entryValue) in value {
        object[key] = try jsonCompatibleValue(entryValue ?? nil)
      }
      return object
    case let value as [Any?]:
      return try value.map { try jsonCompatibleValue($0) }
    case let value as Bool:
      return value
    case let value as String:
      return value
    case let value as UInt64:
      return value <= UInt64(Int64.max) ? NSNumber(value: value) : String(value)
    case let value as UInt32:
      return NSNumber(value: value)
    case let value as UInt16:
      return NSNumber(value: value)
    case let value as UInt8:
      return NSNumber(value: value)
    case let value as Int64:
      return NSNumber(value: value)
    case let value as Int32:
      return NSNumber(value: value)
    case let value as Int:
      return NSNumber(value: value)
    case let value as Double:
      return NSNumber(value: value)
    case let value as Float:
      return NSNumber(value: value)
    case let value as NSNumber:
      return value
    default:
      return String(describing: value)
    }
  }

}
