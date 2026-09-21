package com.utexo.rgb_sdk_flutter

import org.utexo.rgblightningnode.NoPointer
import org.utexo.rgblightningnode.NativeExternalSigner
import org.utexo.rgblightningnode.SdkLdkChainSync
import org.utexo.rgblightningnode.SdkNode
import org.utexo.rgblightningnode.SdkUnlockRequest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertSame
import kotlin.test.assertTrue

internal class RgbSdkFlutterPluginTest {
    private val plugin = RgbSdkFlutterPlugin()

    @Test
    fun nativeArtifactInfoMatchesPinnedAndroidArtifact() {
        val info = plugin.getNativeArtifactInfo()

        assertEquals("android", info.platform)
        assertEquals(ReleaseBaseline.RLN_VERSION, info.rlnVersion)
        assertEquals(ReleaseBaseline.REACT_NATIVE_VERSION, info.reactNativeParityVersion)
        assertEquals("pigeon-bootstrap", info.bridge)
        assertEquals(ReleaseBaseline.ANDROID_MAVEN_COORDINATE, info.nativeArtifact)
    }

    @Test
    fun chainSyncFactorySelectsTransactionAndBlockBackends() {
        val transactionSync = RlnChainSyncFactory.create(
            bitcoindRpcUsername = null,
            bitcoindRpcPassword = null,
            bitcoindRpcHost = null,
            bitcoindRpcPort = null,
            indexerUrl = "electrum.example:50001"
        )
        assertTrue(transactionSync is SdkLdkChainSync.TransactionSync)
        assertEquals("electrum.example:50001", transactionSync.indexerUrl)

        val blockSync = RlnChainSyncFactory.create(
            bitcoindRpcUsername = "rpc-user",
            bitcoindRpcPassword = "rpc-password",
            bitcoindRpcHost = "127.0.0.1",
            bitcoindRpcPort = 18_443,
            indexerUrl = "ignored.example:50001"
        )
        assertTrue(blockSync is SdkLdkChainSync.BlockSync)
        assertEquals("rpc-user", blockSync.bitcoindRpcUsername)
        assertEquals("rpc-password", blockSync.bitcoindRpcPassword)
        assertEquals("127.0.0.1", blockSync.bitcoindRpcHost)
        assertEquals(18_443.toUShort(), blockSync.bitcoindRpcPort)
    }

    @Test
    fun chainSyncFactoryRejectsPartialOrInvalidConfiguration() {
        val partial = assertFailsWith<RlnChainSyncConfigurationException> {
            RlnChainSyncFactory.create(
                bitcoindRpcUsername = "rpc-user",
                bitcoindRpcPassword = null,
                bitcoindRpcHost = null,
                bitcoindRpcPort = null,
                indexerUrl = "electrum.example:50001"
            )
        }
        assertEquals("bitcoindRpc", partial.field)

        val missing = assertFailsWith<RlnChainSyncConfigurationException> {
            RlnChainSyncFactory.create(null, null, null, null, null)
        }
        assertEquals("indexerUrl", missing.field)

        for (port in listOf(0L, 65_536L)) {
            val invalidPort = assertFailsWith<RlnChainSyncConfigurationException> {
                RlnChainSyncFactory.create(
                    bitcoindRpcUsername = "rpc-user",
                    bitcoindRpcPassword = "rpc-password",
                    bitcoindRpcHost = "127.0.0.1",
                    bitcoindRpcPort = port,
                    indexerUrl = null
                )
            }
            assertEquals("bitcoindRpcPort", invalidPort.field)
        }

        val blankIndexer = assertFailsWith<RlnChainSyncConfigurationException> {
            RlnChainSyncFactory.create(null, null, null, null, " \n ")
        }
        assertEquals("indexerUrl", blankIndexer.field)

        for ((username, host, field) in listOf(
            Triple(" ", "127.0.0.1", "bitcoindRpcUsername"),
            Triple("rpc-user", "\t", "bitcoindRpcHost")
        )) {
            val blankRpcField = assertFailsWith<RlnChainSyncConfigurationException> {
                RlnChainSyncFactory.create(
                    bitcoindRpcUsername = username,
                    bitcoindRpcPassword = "",
                    bitcoindRpcHost = host,
                    bitcoindRpcPort = 18_443,
                    indexerUrl = null
                )
            }
            assertEquals(field, blankRpcField.field)
        }
    }

    @Test
    fun backupFailsAsNativeBlockedWithoutLeakingArguments() {
        val error = assertFailsWith<FlutterError> {
            plugin.rlnBackup(
                nodeId = 1,
                backupPath = "/tmp/secret-backup-path",
                password = "super-secret-password"
            )
        }

        assertEquals("UnsupportedOperationException", error.code)
        assertEquals("rlnBackup is not available in current Android RLN bindings", error.message)
        assertFalse(error.message.orEmpty().contains("secret"))

        val details = error.details as Map<*, *>
        assertEquals("rlnBackup", details["operation"])
        assertEquals("rln-parity", details["phase"])
    }

    @Test
    fun externalSignerRgsFailsBeforeNativeLookup() {
        val error = assertFailsWith<FlutterError> {
            plugin.rlnUnlockNodeWithNativeExternalSigner(9999, 9999,
                null, null, null, null, null, null, emptyList(), null,
                "https://rgs.example")
        }
        assertEquals("UnsupportedOperationException", error.code)
        assertEquals("unsupported", (error.details as Map<*, *>)["category"])
    }

    @Test
    fun sendRgbRejectsSkipSyncBeforeNativeNodeLookup() {
        val error = assertFailsWith<FlutterError> {
            plugin.rlnSendRgb(
                nodeId = 1,
                donation = false,
                feeRate = 1.5,
                minConfirmations = 1,
                skipSync = true,
                assetId = "asset",
                recipientId = "recipient",
                amount = 100,
                transportEndpoints = listOf("rpc://127.0.0.1:3003/json-rpc"),
                witnessAmountSat = null,
                witnessBlinding = null
            )
        }

        assertEquals("UnsupportedOperationException", error.code)
        assertEquals(
            "rlnSendRgb skipSync=true is not supported by the pinned RLN native artifact.",
            error.message
        )

        val details = error.details as Map<*, *>
        assertEquals("rlnSendRgb", details["operation"])
        assertEquals("skipSync", details["field"])
    }

    @Test
    fun createNodeRejectsInvalidUnsignedInputsBeforeNativeCreate() {
        val negativePort = assertFailsWith<FlutterError> {
            plugin.rlnCreateNode(
                storageDirPath = uniquePath("negative-port"),
                daemonListeningPort = -1,
                ldkPeerListeningPort = 9735,
                network = "regtest",
                maxMediaUploadSizeMb = 5,
                enableVirtualChannelsV0 = null,
                virtualPeerPubkeys = null,
                vssUrl = null,
                vssAllowHttp = false,
                vssAllowEmptyRestore = false,
                lspBaseUrl = null,
                lspBearerToken = null,
                reuseAddresses = false
            )
        }
        assertInvalidArgument(negativePort, operation = "rlnCreateNode", field = "daemonListeningPort")

        val oversizedMediaLimit = assertFailsWith<FlutterError> {
            plugin.rlnCreateNode(
                storageDirPath = uniquePath("oversized-media"),
                daemonListeningPort = 3000,
                ldkPeerListeningPort = 9735,
                network = "regtest",
                maxMediaUploadSizeMb = 65_536,
                enableVirtualChannelsV0 = null,
                virtualPeerPubkeys = null,
                vssUrl = null,
                vssAllowHttp = false,
                vssAllowEmptyRestore = false,
                lspBaseUrl = null,
                lspBearerToken = null,
                reuseAddresses = false
            )
        }
        assertInvalidArgument(oversizedMediaLimit, operation = "rlnCreateNode", field = "maxMediaUploadSizeMb")
    }

    @Test
    fun createNodeRejectsRelativeStorageBeforeNativeCreate() {
        val error = assertFailsWith<FlutterError> {
            plugin.rlnCreateNode(
                storageDirPath = "relative/storage",
                daemonListeningPort = 3000,
                ldkPeerListeningPort = 9735,
                network = "regtest",
                maxMediaUploadSizeMb = 5,
                enableVirtualChannelsV0 = null,
                virtualPeerPubkeys = null,
                vssUrl = null,
                vssAllowHttp = false,
                vssAllowEmptyRestore = false,
                lspBaseUrl = null,
                lspBearerToken = null,
                reuseAddresses = false
            )
        }

        assertInvalidArgument(error, operation = "rlnCreateNode", field = "storageDirPath")
        assertTrue(error.message.orEmpty().contains("absolute path"))
    }

    @Test
    fun bridgeRejectsFractionalFeeRateBeforeNativeNodeLookup() {
        val error = assertFailsWith<FlutterError> {
            plugin.rlnSendBtc(
                nodeId = 9_999,
                amount = 1,
                address = "bcrt1destination",
                feeRate = 1.5,
                skipSync = false
            )
        }

        assertInvalidArgument(error, operation = "rlnSendBtc", field = "feeRate")
        assertTrue(error.message.orEmpty().contains("integer fee rate"))
    }

    @Test
    fun bridgeRejectsGroupTwoNumericBoundaryFieldsBeforeNativeNodeLookup() {
        val openChannel = assertFailsWith<FlutterError> {
            plugin.rlnOpenChannel(
                nodeId = 9_999,
                peerPubkeyAndOptAddr = "peer@127.0.0.1:9735",
                capacitySat = -1,
                pushMsat = 0,
                publicChannel = false,
                withAnchors = true,
                feeBaseMsat = null,
                feeProportionalMillionths = null,
                temporaryChannelId = null,
                assetId = null,
                assetAmount = null,
                pushAssetAmount = null,
                virtualOpenMode = null
            )
        }
        assertInvalidArgument(openChannel, operation = "rlnOpenChannel", field = "capacitySat")

        val invoice = assertFailsWith<FlutterError> {
            plugin.rlnLnInvoice(
                nodeId = 9_999,
                amtMsat = null,
                expirySec = -1,
                assetId = null,
                assetAmount = null,
                paymentHash = null,
                minFinalCltvExpiryDelta = null,
                descriptionHash = "description-hash"
            )
        }
        assertInvalidArgument(invoice, operation = "rlnLnInvoice", field = "expirySec")

        val sendPayment = assertFailsWith<FlutterError> {
            plugin.rlnSendPayment(
                nodeId = 9_999,
                invoice = "lnbc1invoice",
                amtMsat = -1,
                assetId = null,
                assetAmount = null
            )
        }
        assertInvalidArgument(sendPayment, operation = "rlnSendPayment", field = "amtMsat")

        val inflate = assertFailsWith<FlutterError> {
            plugin.rlnInflate(
                nodeId = 9_999,
                assetId = "asset",
                inflationAmounts = listOf(-1),
                feeRate = 1.0,
                minConfirmations = 1
            )
        }
        assertInvalidArgument(inflate, operation = "rlnInflate", field = "inflationAmounts[0]")
    }

    @Test
    fun rgbInvoiceRejectsUnknownAssignmentKindBeforeNativeNodeLookup() {
        val error = assertFailsWith<FlutterError> {
            plugin.rlnRgbInvoice(
                nodeId = 9_999,
                assetId = "asset",
                assignmentAmount = 1,
                durationSeconds = null,
                minConfirmations = 1,
                witness = false,
                assignmentKind = "Mystery"
            )
        }

        assertInvalidArgument(error, operation = "rlnRgbInvoice", field = "assignmentKind")
        assertTrue(error.message.orEmpty().contains("Unknown assignmentKind"))
    }

    @Test
    fun bridgeReportsUnknownNodeForGroupTwoMethodFamilies() {
        val cases = listOf<Pair<String, () -> Unit>>(
            "rlnInitNodeWithNativeExternalSigner" to { plugin.rlnInitNodeWithNativeExternalSigner(9_999, 8_888) },
            "rlnAttachNativeExternalSigner" to { plugin.rlnAttachNativeExternalSigner(9_999, 8_888) },
            "rlnNodeInfo" to { plugin.rlnNodeInfo(9_999) },
            "rlnCheckIndexerUrl" to { plugin.rlnCheckIndexerUrl(9_999, "electrum://127.0.0.1:50001") },
            "rlnListPeers" to { plugin.rlnListPeers(9_999) },
            "rlnListChannels" to { plugin.rlnListChannels(9_999) },
            "rlnListPayments" to { plugin.rlnListPayments(9_999) },
            "rlnVssBackup" to { plugin.rlnVssBackup(9_999) },
            "rlnVssClearFence" to { plugin.rlnVssClearFence(9_999, "never-log-this-password") },
            "rlnRotateAddress" to { plugin.rlnRotateAddress(9_999) },
            "rlnSignMessage" to { plugin.rlnSignMessage(9_999, "message") },
            "rlnVerifyMessage" to { plugin.rlnVerifyMessage(9_999, "message", "signature") },
            "rlnListTransactionsByTxid" to {
                plugin.rlnListTransactionsByTxid(9_999, "txid", false)
            },
            "rlnListTransfersByTxid" to {
                plugin.rlnListTransfersByTxid(9_999, "txid")
            }
        )

        for ((operation, call) in cases) {
            val error = assertFailsWith<FlutterError> { call() }
            val details = error.details as Map<*, *>
            assertEquals(operation, details["operation"])
            assertEquals("NodeNotFound", error.code)
            assertEquals("notFound", details["category"])
        }
    }

    @Test
    fun storagePolicyAcceptsOwnerOnlyDirectory() {
        val access = FakeStorageDirectoryAccess(
            metadata = RlnStorageDirectoryMetadata(
                isDirectory = true,
                ownerId = 1000,
                permissions = 0x1C0
            )
        )

        RlnStorageDirectoryPolicy(access).prepare("/data/user/0/app/node")

        assertEquals(listOf("/data/user/0/app/node"), access.createdPaths)
    }

    @Test
    fun storagePolicyRejectsBroadExistingDirectoryWithoutMutatingIt() {
        val metadata = RlnStorageDirectoryMetadata(
            isDirectory = true,
            ownerId = 1000,
            permissions = 0x1ED
        )
        val access = FakeStorageDirectoryAccess(metadata = metadata)

        val error = assertFailsWith<RlnStorageDirectoryPolicyException> {
            RlnStorageDirectoryPolicy(access).prepare("/data/user/0/app/node")
        }

        assertTrue(error.message.orEmpty().contains("mode 0700"))
        assertSame(metadata, access.metadata)
        assertEquals(listOf("/data/user/0/app/node"), access.createdPaths)
    }

    @Test
    fun storagePolicyRejectsOwnerOnlyButUnusableDirectory() {
        val access = FakeStorageDirectoryAccess(
            metadata = RlnStorageDirectoryMetadata(
                isDirectory = true,
                ownerId = 1000,
                permissions = 0x180
            )
        )

        val error = assertFailsWith<RlnStorageDirectoryPolicyException> {
            RlnStorageDirectoryPolicy(access).prepare("/data/user/0/app/node")
        }

        assertTrue(error.message.orEmpty().contains("mode 0700"))
    }

    @Test
    fun storagePolicyRejectsWrongOwnerAndNonDirectory() {
        val wrongOwner = FakeStorageDirectoryAccess(
            metadata = RlnStorageDirectoryMetadata(
                isDirectory = true,
                ownerId = 2000,
                permissions = 0x1C0
            )
        )
        val wrongOwnerError = assertFailsWith<RlnStorageDirectoryPolicyException> {
            RlnStorageDirectoryPolicy(wrongOwner).prepare("/data/user/0/app/node")
        }
        assertTrue(wrongOwnerError.message.orEmpty().contains("current process user"))

        val nonDirectory = FakeStorageDirectoryAccess(
            metadata = RlnStorageDirectoryMetadata(
                isDirectory = false,
                ownerId = 1000,
                permissions = 0x180
            )
        )
        val nonDirectoryError = assertFailsWith<RlnStorageDirectoryPolicyException> {
            RlnStorageDirectoryPolicy(nonDirectory).prepare("/data/user/0/app/node")
        }
        assertTrue(nonDirectoryError.message.orEmpty().contains("must identify a directory"))
    }

    @Test
    fun nodeStoreRejectsDuplicateActiveStoragePathAndReusesShutdownPath() {
        val path = uniquePath("reuse")
        val firstNode = CloseTrackingSdkNode()
        val replacementNode = CloseTrackingSdkNode()
        val duplicateNode = CloseTrackingSdkNode()
        var nodeId: Long? = null

        try {
            val firstId = plugin.nodeStore.create(firstNode, path)
            nodeId = firstId
            assertSame(firstNode, plugin.nodeStore.get(firstId))
            assertFailsWith<RlnStateConflict> { plugin.nodeStore.ensureStorageAvailable(path) }
            assertEquals(RlnNodeStore.NodeLifecycleState.CREATED, plugin.nodeStore.getState(firstId))

            val duplicate = assertFailsWith<RlnStateConflict> {
                plugin.nodeStore.create(duplicateNode, path)
            }
            assertFalse(duplicate.message.orEmpty().contains(path))

            plugin.nodeStore.markShutdown(firstId)
            plugin.nodeStore.ensureStorageAvailable(path)
            val reusedId = plugin.nodeStore.create(replacementNode, path)
            assertTrue(firstId != reusedId)
            nodeId = reusedId
            plugin.nodeStore.remove(firstId)
            assertSame(replacementNode, plugin.nodeStore.get(reusedId))
            assertEquals(RlnNodeStore.NodeLifecycleState.CREATED, plugin.nodeStore.getState(reusedId))
            assertEquals(1, plugin.nodeStore.snapshot().nodeCount)
            assertEquals(path, plugin.nodeStore.snapshot().storageDirByNodeId[reusedId])

            assertEquals(1, firstNode.closeCount)
        } finally {
            nodeId?.let(plugin.nodeStore::remove)
        }

        assertEquals(1, replacementNode.closeCount)
        assertEquals(0, duplicateNode.closeCount)
    }

    @Test
    fun nodeStoreTransitionsUnlockLifecycleAndRemovesClosedNodes() {
        val node = CloseTrackingSdkNode()
        val nodeId = plugin.nodeStore.create(node, uniquePath("lifecycle"))

        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, plugin.nodeStore.beginUnlock(nodeId))
        plugin.nodeStore.rollbackUnlock(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.CREATED, plugin.nodeStore.getState(nodeId))

        plugin.nodeStore.markInitialized(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.INITIALIZED, plugin.nodeStore.getState(nodeId))

        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, plugin.nodeStore.beginUnlock(nodeId))
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.beginUnlock(nodeId)
        }

        plugin.nodeStore.rollbackUnlock(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.INITIALIZED, plugin.nodeStore.getState(nodeId))

        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, plugin.nodeStore.beginUnlock(nodeId))
        plugin.nodeStore.markUnlocked(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKED, plugin.nodeStore.getState(nodeId))
        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKED, plugin.nodeStore.beginUnlock(nodeId))

        plugin.nodeStore.markShutdown(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.SHUTDOWN, plugin.nodeStore.getState(nodeId))
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.markInitialized(nodeId)
        }
        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, plugin.nodeStore.beginUnlock(nodeId))

        plugin.nodeStore.remove(nodeId)
        assertEquals(1, node.closeCount)
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.get(nodeId)
        }
    }

    @Test
    fun nodeStoreRemovesHandlesEvenWhenNativeCloseFails() {
        val node = ThrowingCloseSdkNode()
        val signer = ThrowingCloseNativeSigner()
        val nodeId = plugin.nodeStore.create(node, uniquePath("close-failure"))
        val signerId = plugin.nodeStore.createSigner(signer)

        assertFailsWith<RuntimeException> {
            plugin.nodeStore.remove(nodeId)
        }
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.get(nodeId)
        }

        assertFailsWith<RuntimeException> {
            plugin.nodeStore.removeSigner(signerId)
        }
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.getSigner(signerId)
        }

        val remainingNodeId = plugin.nodeStore.create(
            ThrowingCloseSdkNode(),
            uniquePath("clear-close-failure")
        )
        val remainingSignerId = plugin.nodeStore.createSigner(ThrowingCloseNativeSigner())

        assertFailsWith<RuntimeException> {
            plugin.nodeStore.clearAll()
        }
        assertEquals(0, plugin.nodeStore.snapshot().nodeCount)
        assertEquals(0, plugin.nodeStore.snapshot().signerCount)
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.get(remainingNodeId)
        }
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.getSigner(remainingSignerId)
        }
    }

    @Test
    fun nodeStoreClosesNativeSignerWhenRemoved() {
        val signer = CloseTrackingNativeSigner()
        val signerId = plugin.nodeStore.createSigner(signer)

        assertSame(signer, plugin.nodeStore.getSigner(signerId))
        plugin.nodeStore.removeSigner(signerId)

        assertEquals(1, signer.closeCount)
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.getSigner(signerId)
        }
    }

    @Test
    fun nodeStoreClearAllClosesNodesAndSignersAndResetsHandles() {
        val node = CloseTrackingSdkNode()
        val signer = CloseTrackingNativeSigner()
        val nodeId = plugin.nodeStore.create(node, uniquePath("clear-all"))
        val signerId = plugin.nodeStore.createSigner(signer)

        plugin.nodeStore.clearAll()

        assertEquals(1, node.shutdownCount)
        assertEquals(1, node.closeCount)
        assertEquals(1, signer.closeCount)
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.get(nodeId)
        }
        assertFailsWith<IllegalStateException> {
            plugin.nodeStore.getSigner(signerId)
        }
    }

    private fun assertInvalidArgument(error: FlutterError, operation: String, field: String) {
        assertEquals("invalidArgument", error.code)
        val details = error.details as Map<*, *>
        assertEquals(operation, details["operation"])
        assertEquals(field, details["field"])
    }

    @Test
    fun shutdownFailureStillReleasesAllHandles() {
        var closed = false
        val failing = object : SdkNode(NoPointer) {
            override fun shutdown() { throw Exception("shutdown failed") }
            override fun close() { closed = true }
        }
        val healthy = CloseTrackingSdkNode()
        val signer = CloseTrackingNativeSigner()
        plugin.nodeStore.create(failing, uniquePath("shutdown-failure"))
        plugin.nodeStore.create(healthy, uniquePath("shutdown-survivor"))
        plugin.nodeStore.createSigner(signer)

        assertFailsWith<Exception> { plugin.nodeStore.clearAll() }

        assertTrue(closed)
        assertEquals(1, healthy.shutdownCount)
        assertEquals(1, healthy.closeCount)
        assertEquals(1, signer.closeCount)
        assertEquals(0, plugin.nodeStore.snapshot().nodeCount)
        assertEquals(0, plugin.nodeStore.snapshot().signerCount)
    }

    @Test
    fun previouslyShutdownNodeIsNotShutdownTwice() {
        val node = CloseTrackingSdkNode()
        val id = plugin.nodeStore.create(node, uniquePath("shutdown-once"))
        plugin.rlnShutdown(id)
        plugin.nodeStore.remove(id)
        assertEquals(1, node.shutdownCount)
        assertEquals(1, node.closeCount)
    }

    @Test
    fun engineCleanupDoesNotTouchAnotherEngine() {
        val other = RgbSdkFlutterPlugin()
        val mine = plugin.nodeStore.create(CloseTrackingSdkNode(), uniquePath("engine-a"))
        val theirs = other.nodeStore.create(CloseTrackingSdkNode(), uniquePath("engine-b"))
        try {
            plugin.closeEngine().get(5, java.util.concurrent.TimeUnit.SECONDS)
            assertFailsWith<IllegalStateException> { plugin.nodeStore.get(mine) }
            other.nodeStore.get(theirs)
            assertFailsWith<FlutterError> { plugin.rlnShutdown(mine) }
        } finally {
            other.nodeStore.remove(theirs)
        }
    }

    private fun uniquePath(label: String): String {
        return "/tmp/rgb-sdk-flutter-native-test-$label-${System.nanoTime()}"
    }

    @Test
    fun engineCleanupWaitsForInFlightNativeOperation() {
        val entered = java.util.concurrent.CountDownLatch(1)
        val release = java.util.concurrent.CountDownLatch(1)
        val node = object : SdkNode(NoPointer) {
            @Volatile var closed = false
            override fun shutdown() {
                entered.countDown()
                check(release.await(5, java.util.concurrent.TimeUnit.SECONDS))
            }
            override fun close() { closed = true }
        }
        val id = plugin.nodeStore.create(node, uniquePath("inflight"))
        val operation = java.util.concurrent.CompletableFuture.runAsync { plugin.rlnShutdown(id) }
        try {
            assertTrue(entered.await(5, java.util.concurrent.TimeUnit.SECONDS))
            val cleanup = plugin.closeEngine()
            assertFalse(cleanup.isDone)
            assertFalse(node.closed)
            release.countDown()
            operation.get(5, java.util.concurrent.TimeUnit.SECONDS)
            cleanup.get(5, java.util.concurrent.TimeUnit.SECONDS)
            assertTrue(node.closed)
            assertEquals(0, plugin.nodeStore.snapshot().nodeCount)
            assertFailsWith<FlutterError> { plugin.rlnShutdown(id) }
        } finally {
            release.countDown()
            plugin.closeEngine().get(5, java.util.concurrent.TimeUnit.SECONDS)
        }
    }

    @Test
    fun engineCleanupWaitsForInFlightUnlock() {
        val entered = java.util.concurrent.CountDownLatch(1)
        val release = java.util.concurrent.CountDownLatch(1)
        val node = object : SdkNode(NoPointer) {
            @Volatile var closed = false
            override fun unlock(request: SdkUnlockRequest) {
                entered.countDown()
                check(release.await(5, java.util.concurrent.TimeUnit.SECONDS))
            }
            override fun shutdown() {}
            override fun close() { closed = true }
        }
        val id = plugin.nodeStore.create(node, uniquePath("unlock-drain"))
        val operation = java.util.concurrent.CompletableFuture.runAsync {
            plugin.rlnUnlockNode(id, "test-only", null, null, null, null,
                "electrum://127.0.0.1:50001", null, emptyList(), null, null)
        }
        try {
            assertTrue(entered.await(5, java.util.concurrent.TimeUnit.SECONDS))
            val cleanup = plugin.closeEngine()
            assertFalse(cleanup.isDone)
            assertFalse(node.closed)
            release.countDown()
            operation.get(5, java.util.concurrent.TimeUnit.SECONDS)
            cleanup.get(5, java.util.concurrent.TimeUnit.SECONDS)
            assertTrue(node.closed)
            assertEquals(0, plugin.nodeStore.snapshot().nodeCount)
            assertFailsWith<FlutterError> { plugin.rlnInitNode(id, "test", null) }
            assertFailsWith<FlutterError> { plugin.rlnDestroyNode(id) }
            assertFailsWith<FlutterError> { plugin.rlnDestroyNativeExternalSigner(1) }
        } finally {
            release.countDown()
            plugin.closeEngine().get(5, java.util.concurrent.TimeUnit.SECONDS)
        }
    }

    private class CloseTrackingSdkNode : SdkNode(NoPointer) {
        var closeCount = 0
            private set
        var shutdownCount = 0
            private set

        override fun shutdown() { shutdownCount += 1 }

        override fun close() {
            closeCount += 1
        }
    }

    private class CloseTrackingNativeSigner : NativeExternalSigner(NoPointer) {
        var closeCount = 0
            private set

        override fun close() {
            closeCount += 1
        }
    }

    private class ThrowingCloseSdkNode : SdkNode(NoPointer) {
        override fun shutdown() {}
        override fun close() {
            throw RuntimeException("node close failed")
        }
    }

    private class ThrowingCloseNativeSigner : NativeExternalSigner(NoPointer) {
        override fun close() {
            throw RuntimeException("signer close failed")
        }
    }

    private class FakeStorageDirectoryAccess(
        val metadata: RlnStorageDirectoryMetadata,
        override val effectiveUserId: Int = 1000
    ) : RlnStorageDirectoryAccess {
        val createdPaths = mutableListOf<String>()

        override fun createOwnerOnlyDirectories(path: String) {
            createdPaths += path
        }

        override fun metadata(path: String): RlnStorageDirectoryMetadata {
            return metadata
        }
    }
}
