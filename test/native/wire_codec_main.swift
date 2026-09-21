import Foundation

// Only the Pigeon envelope is substituted. The production codec compiles into
// this host test unchanged; this is not Flutter engine or RLN execution proof.
struct RlnWireResponse { let json: String }
struct PigeonError: Error {
  let code: String
  let message: String?
  let details: Any?
}

@main
struct WireCodecTest {
  static func main() throws {
    let response = try RlnWireCodec.encode([
      "maximum": UInt64.max,
      "zero": Int64(0),
      "one": Int64(1),
      "null": NSNull(),
      "nested": ["value": NSNull()],
      "enabled": true
    ] as [String: Any])
    let decoded = try JSONSerialization.jsonObject(with: Data(response.json.utf8)) as! [String: Any]
    precondition(decoded["maximum"] as? String == "18446744073709551615")
    precondition(decoded["zero"] as? Int == 0)
    precondition(decoded["one"] as? Int == 1)
    precondition(decoded["null"] is NSNull)
    precondition((decoded["nested"] as? [String: Any])?["value"] is NSNull)
    precondition(decoded["enabled"] as? Bool == true)
    precondition(response.json.contains("\"zero\":0"))
    precondition(response.json.contains("\"one\":1"))
    print("Swift production wire codec: exact UInt64, integer, boolean and nested null assertions passed.")
  }
}
