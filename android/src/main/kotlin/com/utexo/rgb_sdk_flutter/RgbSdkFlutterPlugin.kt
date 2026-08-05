package com.utexo.rgb_sdk_flutter

import io.flutter.embedding.engine.plugins.FlutterPlugin
import org.utexo.rgblightningnode.AsyncOrderNewHashWire
import org.utexo.rgblightningnode.CancelHodlInvoiceRequest
import org.utexo.rgblightningnode.ClaimHodlInvoiceRequest
import org.utexo.rgblightningnode.LnInvoiceRequest
import org.utexo.rgblightningnode.NativeExternalSigner
import org.utexo.rgblightningnode.SdkExternalSignerBootstrap
import org.utexo.rgblightningnode.SdkInitRequest
import org.utexo.rgblightningnode.SdkNode
import org.utexo.rgblightningnode.SdkUnlockRequest
import org.utexo.rgblightningnode.SdkVssClearFenceRequest
import org.json.JSONArray
import org.json.JSONObject

/** RgbSdkFlutterPlugin */
class RgbSdkFlutterPlugin :
    FlutterPlugin,
    RlnHostApi {
    private val storageDirectoryPolicy = RlnStorageDirectoryPolicy()

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        RlnHostApi.setUp(flutterPluginBinding.binaryMessenger, this)
    }

    override fun getNativeArtifactInfo(): RlnNativeArtifactInfo {
        return RlnNativeArtifactInfo(
            platform = "android",
            rlnVersion = ReleaseBaseline.RLN_VERSION,
            reactNativeParityVersion = ReleaseBaseline.REACT_NATIVE_VERSION,
            bridge = "pigeon-bootstrap",
            nativeArtifact = ReleaseBaseline.ANDROID_MAVEN_COORDINATE
        )
    }

    private fun unsupported(operation: String): Nothing {
        throw FlutterError(
            code = "unsupported",
            message = "$operation is not implemented yet.",
            details = mapOf("operation" to operation, "phase" to "rln-parity")
        )
    }

    private fun <T> runRln(operation: String, block: () -> T): T {
        try {
            @Suppress("UNCHECKED_CAST")
            return pigeonSafeValue(block()) as T
        } catch (e: FlutterError) {
            throw e
        } catch (e: Exception) {
            throw bridgeError(e, operation)
        }
    }

    private fun <T> runRlnWire(operation: String, block: () -> T): RlnWireResponse {
        return wireResponse(runRln(operation, block))
    }

    private fun <T> runRlnWireList(operation: String, block: () -> List<T>): List<RlnWireResponse> {
        return runRln(operation, block).map(::wireResponse)
    }

    private fun wireResponse(value: Any?): RlnWireResponse {
        return RlnWireResponse(json = toJsonValue(value).toString())
    }

    private fun toJsonValue(value: Any?): Any {
        return when (value) {
            null -> JSONObject.NULL
            is Map<*, *> -> JSONObject(
                value.entries.associate { (key, entryValue) ->
                    key.toString() to toJsonValue(entryValue)
                }
            )
            is Iterable<*> -> JSONArray(value.map(::toJsonValue))
            is Array<*> -> JSONArray(value.map(::toJsonValue))
            is Boolean, is Number, is String -> value
            else -> value.toString()
        }
    }

    private fun invalidArgument(operation: String, field: String, message: String): Nothing {
        throw FlutterError(
            code = "invalidArgument",
            message = message,
            details = mapOf("operation" to operation, "field" to field)
        )
    }

    private fun prepareStorageDirectory(path: String, operation: String) {
        try {
            storageDirectoryPolicy.prepare(path)
        } catch (error: RlnStorageDirectoryPolicyException) {
            invalidArgument(
                operation = operation,
                field = "storageDirPath",
                message = error.message ?: "storageDirPath does not satisfy the storage policy."
            )
        }
    }

    private fun requireULong(value: Long, field: String, operation: String): ULong {
        if (value < 0) {
            invalidArgument(operation, field, "$field must be non-negative.")
        }
        return value.toULong()
    }

    private fun requireUInt(value: Long, field: String, operation: String): UInt {
        if (value < 0 || value > UInt.MAX_VALUE.toLong()) {
            invalidArgument(operation, field, "$field must fit in UInt32.")
        }
        return value.toUInt()
    }

    private fun requireUShort(value: Long, field: String, operation: String): UShort {
        if (value < 0 || value > UShort.MAX_VALUE.toLong()) {
            invalidArgument(operation, field, "$field must fit in UInt16.")
        }
        return value.toUShort()
    }

    private fun requireUByte(value: Long, field: String, operation: String): UByte {
        if (value < 0 || value > UByte.MAX_VALUE.toLong()) {
            invalidArgument(operation, field, "$field must fit in UInt8.")
        }
        return value.toUByte()
    }

    private fun requireInt(value: Long, field: String, operation: String): Int {
        if (value < Int.MIN_VALUE || value > Int.MAX_VALUE) {
            invalidArgument(operation, field, "$field must fit in Int32.")
        }
        return value.toInt()
    }

    private fun requireFeeRate(value: Double, field: String, operation: String): ULong {
        if (!value.isFinite() || value < 0 || value > Long.MAX_VALUE.toDouble() || value % 1.0 != 0.0) {
            invalidArgument(operation, field, "$field must be a finite non-negative integer fee rate.")
        }
        return value.toLong().toULong()
    }

    private fun requireULongList(values: List<Long>, field: String, operation: String): List<ULong> {
        return values.mapIndexed { index, value ->
            requireULong(value, "$field[$index]", operation)
        }
    }

    private fun pigeonSafeValue(value: Any?): Any? {
        return when (value) {
            null -> null
            is UByte -> value.toInt()
            is UShort -> value.toInt()
            is UInt -> value.toLong()
            is ULong -> if (value <= Long.MAX_VALUE.toULong()) value.toLong() else value.toString()
            is Enum<*> -> value.name
            is Map<*, *> -> value.entries.associate { entry ->
                pigeonSafeMapKey(entry.key) to pigeonSafeValue(entry.value)
            }
            is Iterable<*> -> value.map(::pigeonSafeValue)
            is Array<*> -> value.map(::pigeonSafeValue)
            else -> value
        }
    }

    private fun pigeonSafeMapKey(key: Any?): Any? {
        return when (key) {
            null -> null
            is String, is Int, is Long, is Boolean, is Double, is Float -> key
            is UByte -> key.toInt()
            is UShort -> key.toInt()
            is UInt -> key.toLong()
            is ULong -> if (key <= Long.MAX_VALUE.toULong()) key.toLong() else key.toString()
            is Enum<*> -> key.name
            else -> key.toString()
        }
    }

    private fun bridgeError(exception: Exception, operation: String): FlutterError {
        return FlutterError(
            code = errorClassName(exception),
            message = parseErrorMessage(exception.message),
            details = mapOf("operation" to operation)
        )
    }

    private fun errorClassName(exception: Exception): String {
        val className = exception.javaClass.name
        return className.split('$').last().split('.').last()
    }

    private fun parseErrorMessage(message: String?): String {
        if (message == null) return "Unknown error"
        return if (message.startsWith("details=", ignoreCase = true)) {
            message.substring(8).trim()
        } else {
            message
        }
    }

    private fun isNodeReady(node: SdkNode): Boolean {
        return try {
            node.nodeInfo().pubkey.isNotBlank()
        } catch (_: Exception) {
            false
        }
    }

    private fun btcBalanceMap(balance: org.utexo.rgblightningnode.BtcBalance): Map<Any?, Any?> {
        return mapOf(
            "settled" to balance.settled,
            "future" to balance.future,
            "spendable" to balance.spendable
        )
    }

    private fun assetBalanceMap(balance: org.utexo.rgblightningnode.AssetBalanceInfo): Map<Any?, Any?> {
        return mapOf(
            "settled" to balance.settled,
            "future" to balance.future,
            "spendable" to balance.spendable,
            "offchainOutbound" to balance.offchainOutbound,
            "offchainInbound" to balance.offchainInbound
        )
    }

    private fun mediaMap(media: org.utexo.rgblightningnode.Media?): Map<Any?, Any?>? {
        if (media == null) return null
        return mapOf(
            "filePath" to media.filePath,
            "digest" to media.digest,
            "mime" to media.mime
        )
    }

    private fun mediaAttachmentMap(attachment: org.utexo.rgblightningnode.MediaAttachment): Map<Any?, Any?> {
        return mapOf(
            "key" to attachment.key,
            "media" to mediaMap(attachment.media)
        )
    }

    private fun tokenLightMap(token: org.utexo.rgblightningnode.TokenLight?): Map<Any?, Any?>? {
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

    private fun assetNiaMap(asset: org.utexo.rgblightningnode.AssetNia): Map<Any?, Any?> {
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

    private fun assetCfaMap(asset: org.utexo.rgblightningnode.AssetCfa): Map<Any?, Any?> {
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

    private fun assetIfaMap(asset: org.utexo.rgblightningnode.AssetIfa): Map<Any?, Any?> {
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
            "rejectListUrl" to asset.rejectListUrl
        )
    }

    private fun assetUdaMap(asset: org.utexo.rgblightningnode.AssetUda): Map<Any?, Any?> {
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

    private fun listAssetsMap(assets: org.utexo.rgblightningnode.ListAssetsResponse): Map<Any?, Any?> {
        return mapOf(
            "nia" to (assets.nia ?: emptyList()).map(::assetNiaMap),
            "uda" to (assets.uda ?: emptyList()).map(::assetUdaMap),
            "cfa" to (assets.cfa ?: emptyList()).map(::assetCfaMap),
            "ifa" to (assets.ifa ?: emptyList()).map(::assetIfaMap)
        )
    }

    private fun channelMap(channel: org.utexo.rgblightningnode.Channel): Map<Any?, Any?> {
        return mapOf(
            "channelId" to channel.channelId,
            "peerPubkey" to channel.peerPubkey,
            "status" to channel.status.name,
            "ready" to channel.ready,
            "capacitySat" to channel.capacitySat,
            "localBalanceSat" to channel.localBalanceSat,
            "outboundBalanceMsat" to channel.outboundBalanceMsat,
            "inboundBalanceMsat" to channel.inboundBalanceMsat,
            "nextOutboundHtlcLimitMsat" to channel.nextOutboundHtlcLimitMsat,
            "nextOutboundHtlcMinimumMsat" to channel.nextOutboundHtlcMinimumMsat,
            "isUsable" to channel.isUsable,
            "public" to channel.public,
            "fundingTxid" to channel.fundingTxid,
            "peerAlias" to channel.peerAlias,
            "shortChannelId" to channel.shortChannelId?.toString(),
            "assetId" to channel.assetId,
            "assetLocalAmount" to channel.assetLocalAmount?.toString(),
            "assetRemoteAmount" to channel.assetRemoteAmount?.toString(),
            "virtualOpenMode" to channel.virtualOpenMode
        )
    }

    private fun paymentMap(payment: org.utexo.rgblightningnode.Payment): Map<Any?, Any?> {
        return mapOf(
            "amtMsat" to payment.amtMsat?.toString(),
            "assetAmount" to payment.assetAmount?.toString(),
            "assetId" to payment.assetId,
            "paymentHash" to payment.paymentHash,
            "paymentType" to payment.paymentType.name,
            "status" to payment.status.name,
            "createdAt" to payment.createdAt,
            "updatedAt" to payment.updatedAt,
            "payeePubkey" to payment.payeePubkey,
            "preimage" to payment.preimage
        )
    }

    private fun apayHashMap(hash: AsyncOrderNewHashWire): Map<Any?, Any?> {
        return mapOf(
            "hashIndex" to hash.hashIndex,
            "paymentHash" to hash.paymentHash
        )
    }

    private fun rgbAllocationMap(allocation: org.utexo.rgblightningnode.RgbAllocation): Map<Any?, Any?> {
        return mapOf(
            "assetId" to allocation.assetId,
            "assignment" to allocation.assignment,
            "settled" to allocation.settled
        )
    }

    private fun blockTimeMap(blockTime: org.utexo.rgblightningnode.BlockTime?): Map<Any?, Any?>? {
        if (blockTime == null) return null
        return mapOf(
            "height" to blockTime.height,
            "timestamp" to blockTime.timestamp
        )
    }

    private fun transactionMap(transaction: org.utexo.rgblightningnode.Transaction): Map<Any?, Any?> {
        return mapOf(
            "transactionType" to transaction.transactionType.name,
            "txid" to transaction.txid,
            "received" to transaction.received,
            "sent" to transaction.sent,
            "fee" to transaction.fee,
            "confirmationTime" to blockTimeMap(transaction.confirmationTime)
        )
    }

    private fun unspentMap(unspent: org.utexo.rgblightningnode.Unspent): Map<Any?, Any?> {
        return mapOf(
            "utxo" to mapOf(
                "outpoint" to unspent.utxo.outpoint,
                "btcAmount" to unspent.utxo.btcAmount,
                "colorable" to unspent.utxo.colorable
            ),
            "rgbAllocations" to unspent.rgbAllocations.map(::rgbAllocationMap)
        )
    }

    private fun decodeRgbInvoiceMap(invoice: org.utexo.rgblightningnode.DecodeRgbInvoiceResponse): Map<Any?, Any?> {
        return mapOf(
            "recipientId" to invoice.recipientId,
            "recipientType" to invoice.recipientType,
            "assetSchema" to invoice.assetSchema,
            "assetId" to invoice.assetId,
            "assignment" to invoice.assignment,
            "network" to invoice.network,
            "expirationTimestamp" to invoice.expirationTimestamp,
            "transportEndpoints" to invoice.transportEndpoints
        )
    }

    private fun transferTransportEndpointMap(endpoint: org.utexo.rgblightningnode.TransferTransportEndpoint): Map<Any?, Any?> {
        return mapOf(
            "endpoint" to endpoint.endpoint,
            "transportType" to endpoint.transportType,
            "used" to endpoint.used
        )
    }

    private fun transferMap(transfer: org.utexo.rgblightningnode.Transfer): Map<Any?, Any?> {
        return mapOf(
            "idx" to transfer.idx,
            "createdAt" to transfer.createdAt,
            "updatedAt" to transfer.updatedAt,
            "status" to transfer.status,
            "requestedAssignment" to transfer.requestedAssignment,
            "assignments" to transfer.assignments,
            "kind" to transfer.kind,
            "txid" to transfer.txid,
            "recipientId" to transfer.recipientId,
            "receiveUtxo" to transfer.receiveUtxo,
            "changeUtxo" to transfer.changeUtxo,
            "expiration" to transfer.expiration,
            "transportEndpoints" to transfer.transportEndpoints.map(::transferTransportEndpointMap)
        )
    }

    private fun rgbInvoiceMap(invoice: org.utexo.rgblightningnode.SdkRgbInvoiceResponse): Map<Any?, Any?> {
        return mapOf(
            "recipientId" to invoice.recipientId,
            "invoice" to invoice.invoice,
            "expirationTimestamp" to invoice.expirationTimestamp,
            "batchTransferIdx" to invoice.batchTransferIdx
        )
    }

    private fun decodeLnInvoiceMap(invoice: org.utexo.rgblightningnode.DecodeLnInvoiceResponse): Map<Any?, Any?> {
        return mapOf(
            "amtMsat" to invoice.amtMsat?.toString(),
            "expirySec" to invoice.expirySec.toString(),
            "timestamp" to invoice.timestamp.toString(),
            "assetId" to invoice.assetId,
            "assetAmount" to invoice.assetAmount?.toString(),
            "paymentHash" to invoice.paymentHash,
            "paymentSecret" to invoice.paymentSecret,
            "payeePubkey" to invoice.payeePubkey,
            "network" to invoice.network
        )
    }

    private fun keysendMap(response: org.utexo.rgblightningnode.SdkKeysendResponse): Map<Any?, Any?> {
        return mapOf(
            "paymentHash" to response.paymentHash,
            "paymentPreimage" to response.paymentPreimage,
            "status" to response.status.name
        )
    }

    private fun sendPaymentMap(response: org.utexo.rgblightningnode.SdkSendPaymentResponse): Map<Any?, Any?> {
        return mapOf(
            "paymentId" to response.paymentId,
            "paymentHash" to response.paymentHash,
            "paymentSecret" to response.paymentSecret,
            "status" to response.status.name
        )
    }

    override fun rlnCreateNode(
        storageDirPath: String,
        daemonListeningPort: Long,
        ldkPeerListeningPort: Long,
        network: String,
        maxMediaUploadSizeMb: Long,
        enableVirtualChannelsV0: Boolean?,
        virtualPeerPubkeys: List<String>?,
        vssUrl: String?,
        vssAllowHttp: Boolean,
        vssAllowEmptyRestore: Boolean,
        lspBaseUrl: String?,
        lspBearerToken: String?,
        reuseAddresses: Boolean
    ): Long {
        return runRln("rlnCreateNode") {
            val initRequest = SdkInitRequest(
                storageDirPath = storageDirPath,
                daemonListeningPort = requireUShort(daemonListeningPort, "daemonListeningPort", "rlnCreateNode"),
                ldkPeerListeningPort = requireUShort(ldkPeerListeningPort, "ldkPeerListeningPort", "rlnCreateNode"),
                network = network,
                maxMediaUploadSizeMb = requireUShort(maxMediaUploadSizeMb, "maxMediaUploadSizeMb", "rlnCreateNode"),
                enableVirtualChannelsV0 = enableVirtualChannelsV0,
                virtualPeerPubkeys = virtualPeerPubkeys?.filter { it.isNotBlank() },
                lspBaseUrl = lspBaseUrl,
                lspBearerToken = lspBearerToken,
                vssUrl = vssUrl,
                vssAllowHttp = vssAllowHttp,
                vssAllowEmptyRestore = vssAllowEmptyRestore,
                reuseAddresses = reuseAddresses
            )
            prepareStorageDirectory(storageDirPath, "rlnCreateNode")
            val node = SdkNode.create(initRequest)
            RlnNodeStore.create(node, storageDirPath)
        }
    }

    override fun rlnInitNode(nodeId: Long, password: String, mnemonic: String?): String {
        try {
            val node = RlnNodeStore.get(nodeId)
            val state = RlnNodeStore.getState(nodeId)
            if (state != RlnNodeStore.NodeLifecycleState.CREATED) {
                throw IllegalStateException("RLN init is not allowed while node is in state: $state")
            }
            val pubkey = node.init(password, mnemonic)
            RlnNodeStore.markInitialized(nodeId)
            return pubkey
        } catch (e: Exception) {
            throw bridgeError(e, "rlnInitNode")
        }
    }

    override fun rlnCreateNativeExternalSigner(
        seedHex: String,
        network: String,
        permissivePolicy: Boolean,
        storageDirPath: String?
    ): Long {
        return runRln("rlnCreateNativeExternalSigner") {
            val signer = if (storageDirPath == null) {
                NativeExternalSigner(seedHex, network, permissivePolicy)
            } else {
                prepareStorageDirectory(storageDirPath, "rlnCreateNativeExternalSigner")
                NativeExternalSigner.newWithStorage(
                    seedHex,
                    network,
                    permissivePolicy,
                    storageDirPath
                )
            }
            RlnNodeStore.createSigner(signer)
        }
    }

    override fun rlnInitNodeWithNativeExternalSigner(nodeId: Long, signerId: Long) {
        runRln("rlnInitNodeWithNativeExternalSigner") {
            val node = RlnNodeStore.get(nodeId)
            val state = RlnNodeStore.getState(nodeId)
            if (state != RlnNodeStore.NodeLifecycleState.CREATED) {
                throw IllegalStateException("RLN init is not allowed while node is in state: $state")
            }
            val signer = RlnNodeStore.getSigner(signerId)
            node.initWithNativeExternalSigner(signer)
            node.detachExternalSigner()
            RlnNodeStore.markInitialized(nodeId)
        }
    }

    override fun rlnAttachNativeExternalSigner(nodeId: Long, signerId: Long) {
        runRln("rlnAttachNativeExternalSigner") {
            val node = RlnNodeStore.get(nodeId)
            val signer = RlnNodeStore.getSigner(signerId)
            node.attachNativeExternalSigner(signer)
        }
    }

    override fun rlnUnlockNodeWithNativeExternalSigner(
        nodeId: Long,
        signerId: Long,
        bitcoindRpcUsername: String?,
        bitcoindRpcPassword: String?,
        bitcoindRpcHost: String?,
        bitcoindRpcPort: Long?,
        indexerUrl: String?,
        proxyEndpoint: String?,
        announceAddresses: List<String>,
        announceAlias: String?,
        gossipRgsServerUrl: String?
    ) {
        try {
            val node = RlnNodeStore.get(nodeId)
            val signer = RlnNodeStore.getSigner(signerId)
            when (RlnNodeStore.beginUnlock(nodeId)) {
                RlnNodeStore.NodeLifecycleState.UNLOCKED -> {
                    if (isNodeReady(node)) {
                        return
                    }
                    throw IllegalStateException("RLN node is marked unlocked but nodeInfo is not available")
                }
                RlnNodeStore.NodeLifecycleState.UNLOCKING -> Unit
                else -> throw IllegalStateException("Unexpected RLN node state before unlock")
            }
            node.unlockWithNativeExternalSigner(
                signer = signer,
                bitcoindRpcUsername = bitcoindRpcUsername,
                bitcoindRpcPassword = bitcoindRpcPassword,
                bitcoindRpcHost = bitcoindRpcHost,
                bitcoindRpcPort = bitcoindRpcPort?.let { requireUShort(it, "bitcoindRpcPort", "rlnUnlockNodeWithNativeExternalSigner") },
                indexerUrl = indexerUrl,
                proxyEndpoint = proxyEndpoint,
                announceAddresses = announceAddresses,
                announceAlias = announceAlias
            )
            RlnNodeStore.markUnlocked(nodeId)
        } catch (e: Exception) {
            RlnNodeStore.rollbackUnlock(nodeId)
            throw bridgeError(e, "rlnUnlockNodeWithNativeExternalSigner")
        }
    }

    override fun rlnDestroyNativeExternalSigner(signerId: Long) {
        RlnNodeStore.removeSigner(signerId)
    }

    override fun rlnInitNodeWithExternalSigner(nodeId: Long, nodePublicKeyHex: String, accountXpubVanilla: String, accountXpubColored: String, masterFingerprint: String, protocolVersion: String, apiLevel: Long) {
        runRln("rlnInitNodeWithExternalSigner") {
            val node = RlnNodeStore.get(nodeId)
            val state = RlnNodeStore.getState(nodeId)
            if (state != RlnNodeStore.NodeLifecycleState.CREATED) {
                throw IllegalStateException("RLN init is not allowed while node is in state: $state")
            }
            node.initWithExternalSigner(
                SdkExternalSignerBootstrap(
                    nodeId = nodePublicKeyHex,
                    accountXpubVanilla = accountXpubVanilla,
                    accountXpubColored = accountXpubColored,
                    masterFingerprint = masterFingerprint,
                    protocolVersion = protocolVersion,
                    apiLevel = requireUInt(apiLevel, "apiLevel", "rlnInitNodeWithExternalSigner")
                )
            )
            RlnNodeStore.markInitialized(nodeId)
        }
    }

    override fun rlnUnlockNode(
        nodeId: Long,
        password: String,
        bitcoindRpcUsername: String?,
        bitcoindRpcPassword: String?,
        bitcoindRpcHost: String?,
        bitcoindRpcPort: Long?,
        indexerUrl: String?,
        proxyEndpoint: String?,
        announceAddresses: List<String>,
        announceAlias: String?,
        gossipRgsServerUrl: String?
    ) {
        try {
            val node = RlnNodeStore.get(nodeId)
            when (RlnNodeStore.beginUnlock(nodeId)) {
                RlnNodeStore.NodeLifecycleState.UNLOCKED -> {
                    if (isNodeReady(node)) {
                        return
                    }
                    throw IllegalStateException("RLN node is marked unlocked but nodeInfo is not available")
                }
                RlnNodeStore.NodeLifecycleState.UNLOCKING -> Unit
                else -> throw IllegalStateException("Unexpected RLN node state before unlock")
            }
            node.unlock(
                SdkUnlockRequest(
                    password = password,
                    bitcoindRpcUsername = bitcoindRpcUsername,
                    bitcoindRpcPassword = bitcoindRpcPassword,
                    bitcoindRpcHost = bitcoindRpcHost,
                    bitcoindRpcPort = bitcoindRpcPort?.let { requireUShort(it, "bitcoindRpcPort", "rlnUnlockNode") },
                    indexerUrl = indexerUrl,
                    proxyEndpoint = proxyEndpoint,
                    announceAddresses = announceAddresses,
                    announceAlias = announceAlias,
                    gossipRgsServerUrl = gossipRgsServerUrl
                )
            )
            RlnNodeStore.markUnlocked(nodeId)
        } catch (e: Exception) {
            RlnNodeStore.rollbackUnlock(nodeId)
            throw bridgeError(e, "rlnUnlockNode")
        }
    }

    override fun rlnDestroyNode(nodeId: Long) {
        RlnNodeStore.remove(nodeId)
    }

    override fun rlnNodeInfo(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnNodeInfo") {
            val info = RlnNodeStore.get(nodeId).nodeInfo()
            mapOf(
                "pubkey" to info.pubkey,
                "numChannels" to info.numChannels,
                "numUsableChannels" to info.numUsableChannels,
                "localBalanceSat" to info.localBalanceSat,
                "eventualCloseFeesSat" to info.eventualCloseFeesSat,
                "pendingOutboundPaymentsSat" to info.pendingOutboundPaymentsSat,
                "numPeers" to info.numPeers,
                "accountXpubVanilla" to info.accountXpubVanilla,
                "accountXpubColored" to info.accountXpubColored,
                "maxMediaUploadSizeMb" to info.maxMediaUploadSizeMb,
                "rgbHtlcMinMsat" to info.rgbHtlcMinMsat,
                "rgbChannelCapacityMinSat" to info.rgbChannelCapacityMinSat,
                "channelCapacityMinSat" to info.channelCapacityMinSat,
                "channelCapacityMaxSat" to info.channelCapacityMaxSat,
                "channelAssetMinAmount" to info.channelAssetMinAmount,
                "channelAssetMaxAmount" to info.channelAssetMaxAmount.toString(),
                "networkNodes" to info.networkNodes,
                "networkChannels" to info.networkChannels,
                "latestRgsSnapshotTimestamp" to info.latestRgsSnapshotTimestamp
            )
        }
    }

    override fun rlnNetworkInfo(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnNetworkInfo") {
            val info = RlnNodeStore.get(nodeId).networkInfo()
            mapOf(
                "network" to info.network,
                "height" to info.height
            )
        }
    }

    override fun rlnListPeers(nodeId: Long): List<RlnWireResponse> {
        return runRlnWireList("rlnListPeers") {
            RlnNodeStore.get(nodeId).listPeers().map { mapOf("pubkey" to it.pubkey) }
        }
    }

    override fun rlnConnectPeer(nodeId: Long, peerPubkeyAndAddr: String) {
        runRln("rlnConnectPeer") {
            RlnNodeStore.get(nodeId).connectpeer(peerPubkeyAndAddr)
        }
    }

    override fun rlnDisconnectPeer(nodeId: Long, peerPubkey: String) {
        runRln("rlnDisconnectPeer") {
            RlnNodeStore.get(nodeId).disconnectpeer(
                org.utexo.rgblightningnode.SdkDisconnectPeerRequest(peerPubkey)
            )
        }
    }

    override fun rlnListChannels(nodeId: Long): List<RlnWireResponse> {
        return runRlnWireList("rlnListChannels") {
            RlnNodeStore.get(nodeId).listChannels().map(::channelMap)
        }
    }

    override fun rlnOpenChannel(nodeId: Long, peerPubkeyAndOptAddr: String, capacitySat: Long, pushMsat: Long, publicChannel: Boolean, withAnchors: Boolean, feeBaseMsat: Long?, feeProportionalMillionths: Long?, temporaryChannelId: String?, assetId: String?, assetAmount: Long?, pushAssetAmount: Long?, virtualOpenMode: String?): RlnWireResponse {
        return runRlnWire("rlnOpenChannel") {
            val request = org.utexo.rgblightningnode.SdkOpenChannelRequest(
                peerPubkeyAndOptAddr = peerPubkeyAndOptAddr,
                capacitySat = requireULong(capacitySat, "capacitySat", "rlnOpenChannel"),
                pushMsat = requireULong(pushMsat, "pushMsat", "rlnOpenChannel"),
                public = publicChannel,
                withAnchors = withAnchors,
                feeBaseMsat = feeBaseMsat?.let { requireUInt(it, "feeBaseMsat", "rlnOpenChannel") },
                feeProportionalMillionths = feeProportionalMillionths?.let { requireUInt(it, "feeProportionalMillionths", "rlnOpenChannel") },
                temporaryChannelId = temporaryChannelId,
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnOpenChannel") },
                pushAssetAmount = pushAssetAmount?.let { requireULong(it, "pushAssetAmount", "rlnOpenChannel") },
                virtualOpenMode = virtualOpenMode
            )
            val response = RlnNodeStore.get(nodeId).openchannel(request)
            mapOf("temporaryChannelId" to response.temporaryChannelId)
        }
    }

    override fun rlnCloseChannel(nodeId: Long, channelId: String, peerPubkey: String, force: Boolean) {
        runRln("rlnCloseChannel") {
            RlnNodeStore.get(nodeId).closechannel(
                org.utexo.rgblightningnode.SdkCloseChannelRequest(
                    channelId = channelId,
                    peerPubkey = peerPubkey,
                    force = force
                )
            )
        }
    }

    override fun rlnListPayments(nodeId: Long): List<RlnWireResponse> {
        return runRlnWireList("rlnListPayments") {
            RlnNodeStore.get(nodeId).listPayments().map(::paymentMap)
        }
    }

    override fun rlnAddress(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnAddress") {
            mapOf("address" to RlnNodeStore.get(nodeId).address().address)
        }
    }

    override fun rlnRotateAddress(nodeId: Long): RlnWireResponse {
        return runRlnWire("rlnRotateAddress") {
            mapOf("address" to RlnNodeStore.get(nodeId).rotateAddress().address)
        }
    }

    override fun rlnSignMessage(nodeId: Long, message: String): RlnWireResponse {
        return runRlnWire("rlnSignMessage") {
            mapOf("signedMessage" to RlnNodeStore.get(nodeId).signMessage(message).signedMessage)
        }
    }

    override fun rlnVerifyMessage(nodeId: Long, message: String, signature: String): RlnWireResponse {
        return runRlnWire("rlnVerifyMessage") {
            mapOf("valid" to RlnNodeStore.get(nodeId).verifyMessage(message, signature).valid)
        }
    }

    override fun rlnAssetBalance(nodeId: Long, assetId: String): RlnWireResponse {
        return runRlnWire("rlnAssetBalance") {
            assetBalanceMap(RlnNodeStore.get(nodeId).assetBalance(assetId))
        }
    }

    override fun rlnBackup(nodeId: Long, backupPath: String, password: String) {
        throw FlutterError(
            code = "UnsupportedOperationException",
            message = "rlnBackup is not available in current Android RLN bindings",
            details = mapOf("operation" to "rlnBackup", "phase" to "rln-parity")
        )
    }

    override fun rlnBtcBalance(nodeId: Long, skipSync: Boolean): RlnWireResponse {
        return runRlnWire("rlnBtcBalance") {
            val balance = RlnNodeStore.get(nodeId).btcBalance(skipSync)
            mapOf(
                "vanilla" to btcBalanceMap(balance.vanilla),
                "colored" to btcBalanceMap(balance.colored)
            )
        }
    }

    override fun rlnCheckIndexerUrl(nodeId: Long, indexerUrl: String): RlnWireResponse {
        return runRlnWire("rlnCheckIndexerUrl") {
            val response = RlnNodeStore.get(nodeId).checkIndexerUrl(indexerUrl)
            mapOf("indexerProtocol" to response.indexerProtocol)
        }
    }

    override fun rlnCheckProxyEndpoint(nodeId: Long, proxyEndpoint: String) {
        runRln("rlnCheckProxyEndpoint") {
            RlnNodeStore.get(nodeId).checkProxyEndpoint(proxyEndpoint)
        }
    }

    override fun rlnCreateUtxos(nodeId: Long, upTo: Boolean, num: Long?, size: Long?, feeRate: Double, skipSync: Boolean) {
        runRln("rlnCreateUtxos") {
            val request = org.utexo.rgblightningnode.SdkCreateUtxosRequest(
                upTo = upTo,
                num = num?.let { requireUByte(it, "num", "rlnCreateUtxos") },
                size = size?.let { requireUInt(it, "size", "rlnCreateUtxos") },
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnCreateUtxos"),
                skipSync = skipSync
            )
            RlnNodeStore.get(nodeId).createutxos(request)
        }
    }

    override fun rlnDecodeLnInvoice(nodeId: Long, invoice: String): RlnWireResponse {
        return runRlnWire("rlnDecodeLnInvoice") {
            decodeLnInvoiceMap(RlnNodeStore.get(nodeId).decodeLnInvoice(invoice))
        }
    }

    override fun rlnDecodeRgbInvoice(nodeId: Long, invoice: String): RlnWireResponse {
        return runRlnWire("rlnDecodeRgbInvoice") {
            decodeRgbInvoiceMap(RlnNodeStore.get(nodeId).decodeRgbInvoice(invoice))
        }
    }

    override fun rlnEstimateFee(nodeId: Long, blocks: Long): RlnWireResponse {
        return runRlnWire("rlnEstimateFee") {
            val response = RlnNodeStore.get(nodeId).estimateFee(
                requireUShort(blocks, "blocks", "rlnEstimateFee")
            )
            mapOf("feeRate" to response.feeRate)
        }
    }

    override fun rlnFailTransfers(nodeId: Long, batchTransferIdx: Long?, noAssetOnly: Boolean, skipSync: Boolean): RlnWireResponse {
        return runRlnWire("rlnFailTransfers") {
            val response = RlnNodeStore.get(nodeId).failtransfers(
                org.utexo.rgblightningnode.SdkFailTransfersRequest(
                    batchTransferIdx = batchTransferIdx?.let { requireInt(it, "batchTransferIdx", "rlnFailTransfers") },
                    noAssetOnly = noAssetOnly,
                    skipSync = skipSync
                )
            )
            mapOf("transfersChanged" to response.transfersChanged)
        }
    }

    override fun rlnGetChannelId(nodeId: Long, temporaryChannelId: String): String {
        return runRln("rlnGetChannelId") {
            RlnNodeStore.get(nodeId).getChannelId(temporaryChannelId)
        }
    }

    override fun rlnGetPayment(nodeId: Long, paymentHash: String): RlnWireResponse {
        return runRlnWire("rlnGetPayment") {
            val node = RlnNodeStore.get(nodeId)
            var lastError: Exception? = null
            for (paymentType in listOf(
                org.utexo.rgblightningnode.PaymentType.OUTBOUND,
                org.utexo.rgblightningnode.PaymentType.INBOUND_AUTO_CLAIM,
                org.utexo.rgblightningnode.PaymentType.INBOUND_HODL
            )) {
                try {
                    return@runRlnWire paymentMap(node.getPayment(paymentHash, paymentType))
                } catch (e: Exception) {
                    lastError = e
                }
            }
            throw lastError ?: IllegalStateException("Payment not found")
        }
    }

    override fun rlnInvoiceStatus(nodeId: Long, invoice: String): RlnWireResponse {
        return runRlnWire("rlnInvoiceStatus") {
            mapOf("status" to RlnNodeStore.get(nodeId).invoiceStatus(invoice).name)
        }
    }

    override fun rlnKeysend(nodeId: Long, destPubkey: String, amtMsat: Long, assetId: String?, assetAmount: Long?): RlnWireResponse {
        return runRlnWire("rlnKeysend") {
            val request = org.utexo.rgblightningnode.SdkKeysendRequest(
                destPubkey = destPubkey,
                amtMsat = requireULong(amtMsat, "amtMsat", "rlnKeysend"),
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnKeysend") }
            )
            val response = RlnNodeStore.get(nodeId).keysend(request)
            keysendMap(response)
        }
    }

    override fun rlnListAssets(nodeId: Long, filterAssetSchemas: List<String>): RlnWireResponse {
        return runRlnWire("rlnListAssets") {
            listAssetsMap(RlnNodeStore.get(nodeId).listAssets(filterAssetSchemas))
        }
    }

    override fun rlnListTransactions(nodeId: Long, skipSync: Boolean): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransactions") {
            RlnNodeStore.get(nodeId).listTransactions(skipSync).map(::transactionMap)
        }
    }

    override fun rlnListTransactionsByTxid(
        nodeId: Long,
        txid: String,
        skipSync: Boolean
    ): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransactionsByTxid") {
            RlnNodeStore.get(nodeId).listTransactionsByTxid(txid, skipSync).map(::transactionMap)
        }
    }

    override fun rlnListTransfers(nodeId: Long, assetId: String): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransfers") {
            RlnNodeStore.get(nodeId).listTransfers(assetId).map(::transferMap)
        }
    }

    override fun rlnListTransfersByTxid(nodeId: Long, txid: String): List<RlnWireResponse> {
        return runRlnWireList("rlnListTransfersByTxid") {
            RlnNodeStore.get(nodeId).listTransfersByTxid(txid).map(::transferMap)
        }
    }

    override fun rlnListUnspents(nodeId: Long, skipSync: Boolean): List<RlnWireResponse> {
        return runRlnWireList("rlnListUnspents") {
            RlnNodeStore.get(nodeId).listUnspents(skipSync).map(::unspentMap)
        }
    }

    override fun rlnLnInvoice(
        nodeId: Long,
        amtMsat: Long?,
        expirySec: Long,
        assetId: String?,
        assetAmount: Long?,
        paymentHash: String?,
        minFinalCltvExpiryDelta: Long?,
        descriptionHash: String?
    ): RlnWireResponse {
        return runRlnWire("rlnLnInvoice") {
            val request = LnInvoiceRequest(
                amtMsat = amtMsat?.let { requireULong(it, "amtMsat", "rlnLnInvoice") },
                expirySec = requireUInt(expirySec, "expirySec", "rlnLnInvoice"),
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnLnInvoice") },
                paymentHash = paymentHash,
                descriptionHash = descriptionHash,
                minFinalCltvExpiryDelta = minFinalCltvExpiryDelta?.let { requireUShort(it, "minFinalCltvExpiryDelta", "rlnLnInvoice") }
            )
            val response = RlnNodeStore.get(nodeId).lnInvoice(request)
            mapOf("invoice" to response.invoice)
        }
    }

    override fun rlnClaimHodlInvoice(nodeId: Long, paymentHash: String, paymentPreimage: String): RlnWireResponse {
        return runRlnWire("rlnClaimHodlInvoice") {
            val response = RlnNodeStore.get(nodeId).claimhodlinvoice(
                ClaimHodlInvoiceRequest(
                    paymentHash = paymentHash,
                    paymentPreimage = paymentPreimage
                )
            )
            mapOf("changed" to response.changed)
        }
    }

    override fun rlnCancelHodlInvoice(nodeId: Long, paymentHash: String) {
        runRln("rlnCancelHodlInvoice") {
            RlnNodeStore.get(nodeId).cancelhodlinvoice(
                CancelHodlInvoiceRequest(paymentHash = paymentHash)
            )
        }
    }

    override fun rlnApayNew(nodeId: Long, hostNodeId: String): RlnWireResponse {
        return runRlnWire("rlnApayNew") {
            val response = RlnNodeStore.get(nodeId).apayNew(hostNodeId)
            mapOf(
                "requestId" to response.requestId,
                "hostNodeId" to response.hostNodeId,
                "protocolVersion" to response.protocolVersion,
                "orderId" to response.orderId,
                "status" to response.status,
                "acceptedThroughIndex" to response.acceptedThroughIndex,
                "nextIndexExpected" to response.nextIndexExpected,
                "unusedHashes" to response.unusedHashes,
                "refillBatchSize" to response.refillBatchSize,
                "firstHashIndex" to response.firstHashIndex,
                "lastHashIndex" to response.lastHashIndex,
                "hashes" to response.hashes.map(::apayHashMap)
            )
        }
    }

    override fun rlnApayNewWithAddress(nodeId: Long, hostNodeId: String, username: String, domain: String): RlnWireResponse {
        return runRlnWire("rlnApayNewWithAddress") {
            val response = RlnNodeStore.get(nodeId).apayNewWithAddress(hostNodeId, username, domain)
            mapOf(
                "requestId" to response.requestId,
                "hostNodeId" to response.hostNodeId,
                "protocolVersion" to response.protocolVersion,
                "orderId" to response.orderId,
                "status" to response.status,
                "acceptedThroughIndex" to response.acceptedThroughIndex,
                "nextIndexExpected" to response.nextIndexExpected,
                "unusedHashes" to response.unusedHashes,
                "refillBatchSize" to response.refillBatchSize,
                "firstHashIndex" to response.firstHashIndex,
                "lastHashIndex" to response.lastHashIndex,
                "hashes" to response.hashes.map(::apayHashMap)
            )
        }
    }

    override fun rlnRefreshTransfers(nodeId: Long, skipSync: Boolean) {
        runRln("rlnRefreshTransfers") {
            RlnNodeStore.get(nodeId).refreshtransfers(
                org.utexo.rgblightningnode.SdkRefreshTransfersRequest(skipSync)
            )
        }
    }

    private fun parseAssignmentKind(rawValue: String?): org.utexo.rgblightningnode.AssignmentKind? {
        return when (rawValue) {
            null -> null
            "Fungible" -> org.utexo.rgblightningnode.AssignmentKind.FUNGIBLE
            "NonFungible" -> org.utexo.rgblightningnode.AssignmentKind.NON_FUNGIBLE
            "InflationRight" -> org.utexo.rgblightningnode.AssignmentKind.INFLATION_RIGHT
            "ReplaceRight" -> org.utexo.rgblightningnode.AssignmentKind.REPLACE_RIGHT
            "Any" -> org.utexo.rgblightningnode.AssignmentKind.ANY
            else -> invalidArgument(
                "rlnRgbInvoice",
                "assignmentKind",
                "Unknown assignmentKind: $rawValue"
            )
        }
    }

    override fun rlnRgbInvoice(
        nodeId: Long,
        assetId: String?,
        assignmentAmount: Long?,
        durationSeconds: Long?,
        minConfirmations: Long,
        witness: Boolean,
        assignmentKind: String?
    ): RlnWireResponse {
        return runRlnWire("rlnRgbInvoice") {
            val request = org.utexo.rgblightningnode.SdkRgbInvoiceRequest(
                assetId = assetId,
                assignmentKind = parseAssignmentKind(assignmentKind),
                assignmentAmount = assignmentAmount?.let { requireULong(it, "assignmentAmount", "rlnRgbInvoice") },
                durationSeconds = durationSeconds?.let { requireUInt(it, "durationSeconds", "rlnRgbInvoice") },
                minConfirmations = requireUByte(minConfirmations, "minConfirmations", "rlnRgbInvoice"),
                witness = witness
            )
            rgbInvoiceMap(RlnNodeStore.get(nodeId).rgbinvoice(request))
        }
    }

    override fun rlnSendBtc(nodeId: Long, amount: Long, address: String, feeRate: Double, skipSync: Boolean): RlnWireResponse {
        return runRlnWire("rlnSendBtc") {
            val request = org.utexo.rgblightningnode.SdkSendBtcRequest(
                amount = requireULong(amount, "amount", "rlnSendBtc"),
                address = address,
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnSendBtc"),
                skipSync = skipSync
            )
            val response = RlnNodeStore.get(nodeId).sendbtc(request)
            mapOf("txid" to response.txid)
        }
    }

    override fun rlnSendPayment(nodeId: Long, invoice: String, amtMsat: Long?, assetId: String?, assetAmount: Long?): RlnWireResponse {
        return runRlnWire("rlnSendPayment") {
            val request = org.utexo.rgblightningnode.SdkSendPaymentRequest(
                invoice = invoice,
                amtMsat = amtMsat?.let { requireULong(it, "amtMsat", "rlnSendPayment") },
                assetId = assetId,
                assetAmount = assetAmount?.let { requireULong(it, "assetAmount", "rlnSendPayment") }
            )
            val response = RlnNodeStore.get(nodeId).sendpayment(request)
            sendPaymentMap(response)
        }
    }

    override fun rlnSendRgb(nodeId: Long, donation: Boolean, feeRate: Double, minConfirmations: Long, skipSync: Boolean, assetId: String, recipientId: String, amount: Long, transportEndpoints: List<String>, witnessAmountSat: Long?, witnessBlinding: Long?): RlnWireResponse {
        return runRlnWire("rlnSendRgb") {
            if (skipSync) {
                throw FlutterError(
                    code = "UnsupportedOperationException",
                    message = "rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.",
                    details = mapOf("operation" to "rlnSendRgb", "field" to "skipSync")
                )
            }
            val witnessData = witnessAmountSat?.let {
                org.utexo.rgblightningnode.WitnessData(
                    amountSat = requireULong(it, "witnessAmountSat", "rlnSendRgb"),
                    blinding = witnessBlinding?.let { value ->
                        requireULong(value, "witnessBlinding", "rlnSendRgb")
                    }
                )
            }
            val recipient = org.utexo.rgblightningnode.RgbRecipient(
                recipientId = recipientId,
                witnessData = witnessData,
                assignmentKind = org.utexo.rgblightningnode.AssignmentKind.FUNGIBLE,
                assignmentAmount = requireULong(amount, "amount", "rlnSendRgb"),
                transportEndpoints = transportEndpoints
            )
            val request = org.utexo.rgblightningnode.SendRgbRequest(
                donation = donation,
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnSendRgb"),
                minConfirmations = requireUByte(minConfirmations, "minConfirmations", "rlnSendRgb"),
                recipientGroups = listOf(
                    org.utexo.rgblightningnode.AssetRecipients(
                        assetId = assetId,
                        recipients = listOf(recipient)
                    )
                )
            )
            val response = RlnNodeStore.get(nodeId).sendRgb(request)
            mapOf(
                "txid" to response.txid,
                "batchTransferIdx" to response.batchTransferIdx
            )
        }
    }

    override fun rlnShutdown(nodeId: Long) {
        runRln("rlnShutdown") {
            val node = RlnNodeStore.get(nodeId)
            node.shutdown()
            RlnNodeStore.markShutdown(nodeId)
        }
    }

    override fun rlnSync(nodeId: Long) {
        runRln("rlnSync") {
            RlnNodeStore.get(nodeId).sync()
        }
    }

    override fun rlnIssueAssetNia(nodeId: Long, ticker: String, name: String, precision: Long, amounts: List<Long>): RlnWireResponse {
        return runRlnWire("rlnIssueAssetNia") {
            val asset = RlnNodeStore.get(nodeId).issueassetnia(
                org.utexo.rgblightningnode.SdkIssueAssetNiaRequest(
                    amounts = requireULongList(amounts, "amounts", "rlnIssueAssetNia"),
                    ticker = ticker,
                    name = name,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetNia")
                )
            )
            assetNiaMap(asset)
        }
    }

    override fun rlnIssueAssetCfa(nodeId: Long, name: String, details: String?, precision: Long, amounts: List<Long>, fileDigest: String?): RlnWireResponse {
        return runRlnWire("rlnIssueAssetCfa") {
            val asset = RlnNodeStore.get(nodeId).issueassetcfa(
                org.utexo.rgblightningnode.SdkIssueAssetCfaRequest(
                    amounts = requireULongList(amounts, "amounts", "rlnIssueAssetCfa"),
                    name = name,
                    details = details,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetCfa"),
                    fileDigest = fileDigest
                )
            )
            assetCfaMap(asset)
        }
    }

    override fun rlnIssueAssetIfa(nodeId: Long, ticker: String, name: String, precision: Long, amounts: List<Long>, inflationAmounts: List<Long>, rejectListUrl: String?): RlnWireResponse {
        return runRlnWire("rlnIssueAssetIfa") {
            val asset = RlnNodeStore.get(nodeId).issueassetifa(
                org.utexo.rgblightningnode.SdkIssueAssetIfaRequest(
                    amounts = requireULongList(amounts, "amounts", "rlnIssueAssetIfa"),
                    inflationAmounts = requireULongList(inflationAmounts, "inflationAmounts", "rlnIssueAssetIfa"),
                    ticker = ticker,
                    name = name,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetIfa"),
                    rejectListUrl = rejectListUrl
                )
            )
            assetIfaMap(asset)
        }
    }

    override fun rlnInflate(
        nodeId: Long,
        assetId: String,
        inflationAmounts: List<Long>,
        feeRate: Double,
        minConfirmations: Long
    ): RlnWireResponse {
        return runRlnWire("rlnInflate") {
            val request = org.utexo.rgblightningnode.InflateRequest(
                assetId = assetId,
                inflationAmounts = requireULongList(
                    inflationAmounts,
                    "inflationAmounts",
                    "rlnInflate"
                ),
                feeRate = requireFeeRate(feeRate, "feeRate", "rlnInflate"),
                minConfirmations = requireUByte(
                    minConfirmations,
                    "minConfirmations",
                    "rlnInflate"
                )
            )
            val response = RlnNodeStore.get(nodeId).inflate(request)
            mapOf("txid" to response.txid)
        }
    }

    override fun rlnIssueAssetUda(nodeId: Long, ticker: String, name: String, details: String?, precision: Long, mediaFileDigest: String?, attachmentsFileDigests: List<String>): RlnWireResponse {
        return runRlnWire("rlnIssueAssetUda") {
            val asset = RlnNodeStore.get(nodeId).issueassetuda(
                org.utexo.rgblightningnode.SdkIssueAssetUdaRequest(
                    ticker = ticker,
                    name = name,
                    details = details,
                    precision = requireUByte(precision, "precision", "rlnIssueAssetUda"),
                    mediaFileDigest = mediaFileDigest,
                    attachmentsFileDigests = attachmentsFileDigests
                )
            )
            assetUdaMap(asset)
        }
    }

    override fun rlnVssBackup(nodeId: Long): Long {
        return runRln("rlnVssBackup") {
            RlnNodeStore.get(nodeId).vssBackup()
        }
    }

    override fun rlnVssClearFence(nodeId: Long, password: String) {
        runRln("rlnVssClearFence") {
            RlnNodeStore.get(nodeId).vssClearFence(
                SdkVssClearFenceRequest(password = password)
            )
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        RlnHostApi.setUp(binding.binaryMessenger, null)
        RlnNodeStore.clearAll()
    }
}
