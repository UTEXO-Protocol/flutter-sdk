package com.utexo.rgb_sdk_flutter

// Pure native asset serialization; no node handles or lifecycle state.
internal object RlnAssetMapper {
    fun assetBalanceMap(balance: org.utexo.rgblightningnode.AssetBalanceInfo): Map<Any?, Any?> {
        return mapOf(
            "settled" to balance.settled,
            "future" to balance.future,
            "spendable" to balance.spendable,
            "offchainOutbound" to balance.offchainOutbound,
            "offchainInbound" to balance.offchainInbound
        )
    }

    fun mediaMap(media: org.utexo.rgblightningnode.Media?): Map<Any?, Any?>? {
        if (media == null) return null
        return mapOf(
            "filePath" to media.filePath,
            "digest" to media.digest,
            "mime" to media.mime
        )
    }

    fun mediaAttachmentMap(attachment: org.utexo.rgblightningnode.MediaAttachment): Map<Any?, Any?> {
        return mapOf(
            "key" to attachment.key,
            "media" to mediaMap(attachment.media)
        )
    }

    fun tokenLightMap(token: org.utexo.rgblightningnode.TokenLight?): Map<Any?, Any?>? {
        if (token == null) return null
        return mapOf(
            "index" to token.index,
            "ticker" to token.ticker,
            "name" to token.name,
            "details" to token.details,
            "embeddedMedia" to token.embeddedMedia,
            "media" to mediaMap(token.media),
            "attachments" to token.attachments.map(::mediaAttachmentMap),
            "reserves" to token.reserves
        )
    }

    fun assetNiaMap(asset: org.utexo.rgblightningnode.AssetNia): Map<Any?, Any?> {
        return mapOf(
            "assetId" to asset.assetId,
            "ticker" to asset.ticker,
            "name" to asset.name,
            "details" to asset.details,
            "precision" to asset.precision,
            "issuedSupply" to asset.issuedSupply.toString(),
            "timestamp" to asset.timestamp,
            "addedAt" to asset.addedAt,
            "balance" to assetBalanceMap(asset.balance),
            "media" to mediaMap(asset.media)
        )
    }

    fun assetBfaMap(asset: org.utexo.rgblightningnode.AssetBfa): Map<Any?, Any?> =
        mapOf(
            "assetId" to asset.assetId, "ticker" to asset.ticker, "name" to asset.name,
            "details" to asset.details, "precision" to asset.precision,
            "initialSupply" to asset.initialSupply.toString(),
            "timestamp" to asset.timestamp, "addedAt" to asset.addedAt,
            "balance" to assetBalanceMap(asset.balance), "media" to mediaMap(asset.media),
            "rejectListUrl" to asset.rejectListUrl
        )

    fun assetCfaMap(asset: org.utexo.rgblightningnode.AssetCfa): Map<Any?, Any?> {
        return mapOf(
            "assetId" to asset.assetId,
            "name" to asset.name,
            "details" to asset.details,
            "precision" to asset.precision,
            "issuedSupply" to asset.issuedSupply.toString(),
            "timestamp" to asset.timestamp,
            "addedAt" to asset.addedAt,
            "balance" to assetBalanceMap(asset.balance),
            "media" to mediaMap(asset.media)
        )
    }

    fun assetIfaMap(asset: org.utexo.rgblightningnode.AssetIfa): Map<Any?, Any?> {
        return mapOf(
            "assetId" to asset.assetId,
            "ticker" to asset.ticker,
            "name" to asset.name,
            "details" to asset.details,
            "precision" to asset.precision,
            "initialSupply" to asset.initialSupply.toString(),
            "maxSupply" to asset.maxSupply.toString(),
            "knownCirculatingSupply" to asset.knownCirculatingSupply.toString(),
            "timestamp" to asset.timestamp,
            "addedAt" to asset.addedAt,
            "balance" to assetBalanceMap(asset.balance),
            "media" to mediaMap(asset.media),
            "rejectListUrl" to asset.rejectListUrl,
            "issuanceLinkRightOutpoint" to asset.issuanceLinkRightOutpoint?.let {
                mapOf("txid" to it.txid, "vout" to it.vout.toLong())
            },
            "linkedFromAssetId" to asset.linkedFromAssetId,
            "linkedToAssetId" to asset.linkedToAssetId
        )
    }

    fun assetUdaMap(asset: org.utexo.rgblightningnode.AssetUda): Map<Any?, Any?> {
        return mapOf(
            "assetId" to asset.assetId,
            "ticker" to asset.ticker,
            "name" to asset.name,
            "details" to asset.details,
            "precision" to asset.precision,
            "timestamp" to asset.timestamp,
            "addedAt" to asset.addedAt,
            "balance" to assetBalanceMap(asset.balance),
            "token" to tokenLightMap(asset.token)
        )
    }

    fun listAssetsMap(assets: org.utexo.rgblightningnode.ListAssetsResponse): Map<Any?, Any?> {
        return mapOf(
            "bfa" to (assets.bfa ?: emptyList()).map(::assetBfaMap),
            "nia" to (assets.nia ?: emptyList()).map(::assetNiaMap),
            "uda" to (assets.uda ?: emptyList()).map(::assetUdaMap),
            "cfa" to (assets.cfa ?: emptyList()).map(::assetCfaMap),
            "ifa" to (assets.ifa ?: emptyList()).map(::assetIfaMap)
        )
    }

}
