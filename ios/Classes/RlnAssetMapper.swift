import Foundation

// Pure native asset serialization; no node handles or lifecycle state.
enum RlnAssetMapper {
  private static func pigeonInteger(_ value: UInt64) -> Any {
    value <= UInt64(Int64.max) ? Int64(value) as Any : String(value)
  }

  static func assetBalanceMap(_ balance: AssetBalanceInfo) -> [String: Any] {
    [
      "settled": pigeonInteger(balance.settled),
      "future": pigeonInteger(balance.future),
      "spendable": pigeonInteger(balance.spendable),
      "offchainOutbound": pigeonInteger(balance.offchainOutbound),
      "offchainInbound": pigeonInteger(balance.offchainInbound),
    ]
  }

  static func mediaMap(_ media: Media?) -> [String: Any]? {
    guard let media else {
      return nil
    }
    return [
      "filePath": media.filePath,
      "digest": media.digest,
      "mime": media.mime,
    ]
  }

  static func mediaAttachmentMap(_ attachment: MediaAttachment) -> [String: Any?] {
    [
      "key": Int64(attachment.key),
      "media": mediaMap(attachment.media),
    ]
  }

  static func tokenLightMap(_ token: TokenLight?) -> [String: Any?]? {
    guard let token else {
      return nil
    }
    return [
      "index": Int64(token.index),
      "ticker": token.ticker,
      "name": token.name,
      "details": token.details,
      "embeddedMedia": token.embeddedMedia,
      "media": mediaMap(token.media),
      "attachments": token.attachments.map(mediaAttachmentMap),
      "reserves": token.reserves,
    ]
  }

  static func assetNiaMap(_ asset: AssetNia) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "ticker": asset.ticker,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "issuedSupply": String(asset.issuedSupply),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "media": mediaMap(asset.media),
    ]
  }

  static func assetBfaMap(_ asset: AssetBfa) -> [String: Any?] {
    [
      "assetId": asset.assetId, "ticker": asset.ticker, "name": asset.name,
      "details": asset.details, "precision": Int64(asset.precision),
      "initialSupply": String(asset.initialSupply),
      "timestamp": asset.timestamp, "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance), "media": mediaMap(asset.media),
      "rejectListUrl": asset.rejectListUrl,
    ]
  }

  static func assetCfaMap(_ asset: AssetCfa) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "issuedSupply": String(asset.issuedSupply),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "media": mediaMap(asset.media),
    ]
  }

  static func assetIfaMap(_ asset: AssetIfa) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "ticker": asset.ticker,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "initialSupply": String(asset.initialSupply),
      "maxSupply": String(asset.maxSupply),
      "knownCirculatingSupply": String(asset.knownCirculatingSupply),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "media": mediaMap(asset.media),
      "rejectListUrl": asset.rejectListUrl,
      "issuanceLinkRightOutpoint": asset.issuanceLinkRightOutpoint.map {
        ["txid": $0.txid, "vout": Int64($0.vout)]
      },
      "linkedFromAssetId": asset.linkedFromAssetId,
      "linkedToAssetId": asset.linkedToAssetId,
    ]
  }

  static func assetUdaMap(_ asset: AssetUda) -> [String: Any?] {
    [
      "assetId": asset.assetId,
      "ticker": asset.ticker,
      "name": asset.name,
      "details": asset.details,
      "precision": Int64(asset.precision),
      "timestamp": asset.timestamp,
      "addedAt": asset.addedAt,
      "balance": assetBalanceMap(asset.balance),
      "token": tokenLightMap(asset.token),
    ]
  }

  static func listAssetsMap(_ assets: ListAssetsResponse) -> [String: Any] {
    [
      "bfa": (assets.bfa ?? []).map(assetBfaMap),
      "nia": (assets.nia ?? []).map(assetNiaMap),
      "uda": (assets.uda ?? []).map(assetUdaMap),
      "cfa": (assets.cfa ?? []).map(assetCfaMap),
      "ifa": (assets.ifa ?? []).map(assetIfaMap),
    ]
  }

}
