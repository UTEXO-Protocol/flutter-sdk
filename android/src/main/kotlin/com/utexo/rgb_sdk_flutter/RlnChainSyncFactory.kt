package com.utexo.rgb_sdk_flutter

import org.utexo.rgblightningnode.SdkLdkChainSync

internal class RlnChainSyncConfigurationException(
    val field: String,
    override val message: String
) : IllegalArgumentException(message)

internal object RlnChainSyncFactory {
    fun create(
        bitcoindRpcUsername: String?,
        bitcoindRpcPassword: String?,
        bitcoindRpcHost: String?,
        bitcoindRpcPort: Long?,
        indexerUrl: String?
    ): SdkLdkChainSync {
        val rpcValues = listOf(
            bitcoindRpcUsername,
            bitcoindRpcPassword,
            bitcoindRpcHost,
            bitcoindRpcPort
        )
        val rpcValueCount = rpcValues.count { it != null }
        if (rpcValueCount in 1..3) {
            throw RlnChainSyncConfigurationException(
                field = "bitcoindRpc",
                message = "Provide all bitcoind RPC parameters or none of them."
            )
        }
        if (rpcValueCount == 4) {
            val port = bitcoindRpcPort!!
            if (port !in 1..UShort.MAX_VALUE.toLong()) {
                throw RlnChainSyncConfigurationException(
                    field = "bitcoindRpcPort",
                    message = "bitcoindRpcPort must be between 1 and 65535."
                )
            }
            return SdkLdkChainSync.BlockSync(
                bitcoindRpcUsername!!,
                bitcoindRpcPassword!!,
                bitcoindRpcHost!!,
                port.toUShort()
            )
        }

        val transactionSyncUrl = indexerUrl?.takeIf { it.isNotBlank() }
            ?: throw RlnChainSyncConfigurationException(
                field = "indexerUrl",
                message = "Provide indexerUrl or complete bitcoind RPC parameters."
            )
        return SdkLdkChainSync.TransactionSync(transactionSyncUrl)
    }
}
