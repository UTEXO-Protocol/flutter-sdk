package com.utexo.rgb_sdk_flutter

import org.utexo.rgblightningnode.NoPointer
import org.utexo.rgblightningnode.NativeExternalSigner
import org.utexo.rgblightningnode.SdkNode
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
        assertInvalidArgument(negativePort, field = "daemonListeningPort")

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
        assertInvalidArgument(oversizedMediaLimit, field = "maxMediaUploadSizeMb")
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

        assertInvalidArgument(error, field = "storageDirPath")
        assertTrue(error.message.orEmpty().contains("absolute path"))
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
            val firstId = RlnNodeStore.create(firstNode, path)
            nodeId = firstId
            assertSame(firstNode, RlnNodeStore.get(firstId))
            assertEquals(RlnNodeStore.NodeLifecycleState.CREATED, RlnNodeStore.getState(firstId))

            val duplicate = assertFailsWith<IllegalStateException> {
                RlnNodeStore.create(duplicateNode, path)
            }
            assertEquals("RLN node already exists for storageDirPath: $path", duplicate.message)

            RlnNodeStore.markShutdown(firstId)
            val reusedId = RlnNodeStore.create(replacementNode, path)
            assertEquals(firstId, reusedId)
            assertSame(replacementNode, RlnNodeStore.get(reusedId))
            assertEquals(RlnNodeStore.NodeLifecycleState.INITIALIZED, RlnNodeStore.getState(reusedId))

            assertEquals(1, firstNode.closeCount)
        } finally {
            nodeId?.let(RlnNodeStore::remove)
        }

        assertEquals(1, replacementNode.closeCount)
        assertEquals(0, duplicateNode.closeCount)
    }

    @Test
    fun nodeStoreTransitionsUnlockLifecycleAndRemovesClosedNodes() {
        val node = CloseTrackingSdkNode()
        val nodeId = RlnNodeStore.create(node, uniquePath("lifecycle"))

        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, RlnNodeStore.beginUnlock(nodeId))
        RlnNodeStore.rollbackUnlock(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.CREATED, RlnNodeStore.getState(nodeId))

        RlnNodeStore.markInitialized(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.INITIALIZED, RlnNodeStore.getState(nodeId))

        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, RlnNodeStore.beginUnlock(nodeId))
        assertFailsWith<IllegalStateException> {
            RlnNodeStore.beginUnlock(nodeId)
        }

        RlnNodeStore.rollbackUnlock(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.INITIALIZED, RlnNodeStore.getState(nodeId))

        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, RlnNodeStore.beginUnlock(nodeId))
        RlnNodeStore.markUnlocked(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKED, RlnNodeStore.getState(nodeId))
        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKED, RlnNodeStore.beginUnlock(nodeId))

        RlnNodeStore.markShutdown(nodeId)
        assertEquals(RlnNodeStore.NodeLifecycleState.SHUTDOWN, RlnNodeStore.getState(nodeId))
        assertEquals(RlnNodeStore.NodeLifecycleState.UNLOCKING, RlnNodeStore.beginUnlock(nodeId))

        RlnNodeStore.remove(nodeId)
        assertEquals(1, node.closeCount)
        assertFailsWith<IllegalStateException> {
            RlnNodeStore.get(nodeId)
        }
    }

    @Test
    fun nodeStoreClosesNativeSignerWhenRemoved() {
        val signer = CloseTrackingNativeSigner()
        val signerId = RlnNodeStore.createSigner(signer)

        assertSame(signer, RlnNodeStore.getSigner(signerId))
        RlnNodeStore.removeSigner(signerId)

        assertEquals(1, signer.closeCount)
        assertFailsWith<IllegalStateException> {
            RlnNodeStore.getSigner(signerId)
        }
    }

    private fun assertInvalidArgument(error: FlutterError, field: String) {
        assertEquals("invalidArgument", error.code)
        val details = error.details as Map<*, *>
        assertEquals("rlnCreateNode", details["operation"])
        assertEquals(field, details["field"])
    }

    private fun uniquePath(label: String): String {
        return "/tmp/rgb-sdk-flutter-native-test-$label-${System.nanoTime()}"
    }

    private class CloseTrackingSdkNode : SdkNode(NoPointer) {
        var closeCount = 0
            private set

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
