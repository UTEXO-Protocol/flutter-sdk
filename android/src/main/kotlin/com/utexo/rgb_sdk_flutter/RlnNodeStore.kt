package com.utexo.rgb_sdk_flutter

import org.utexo.rgblightningnode.NativeExternalSigner
import org.utexo.rgblightningnode.SdkNode

internal class RlnNodeStore {
    private val nodes = mutableMapOf<Long, SdkNode>()
    private val states = mutableMapOf<Long, NodeLifecycleState>()
    private val preUnlockStates = mutableMapOf<Long, NodeLifecycleState>()
    private val storageDirByNodeId = mutableMapOf<Long, String>()
    private var nextId = 1L
    private val signers = mutableMapOf<Long, NativeExternalSigner>()
    private var nextSignerId = 1L

    enum class NodeLifecycleState {
        CREATED,
        INITIALIZED,
        UNLOCKING,
        UNLOCKED,
        SHUTDOWN
    }

    @Synchronized
    fun ensureStorageAvailable(storageDirPath: String) {
        val existing = storageDirByNodeId.entries.firstOrNull {
            it.value == storageDirPath.trim()
        }?.key
        if (existing != null && states[existing] != NodeLifecycleState.SHUTDOWN) {
            throw RlnStateConflict("RLN storage is already owned by an active node")
        }
    }

    @Synchronized
    fun create(node: SdkNode, storageDirPath: String): Long {
        val normalizedPath = storageDirPath.trim()
        if (normalizedPath.isNotEmpty()) {
            val existingId = storageDirByNodeId.entries.firstOrNull { it.value == normalizedPath }?.key
            if (existingId != null) {
                if (states[existingId] == NodeLifecycleState.SHUTDOWN) {
                    remove(existingId)
                } else {
                    throw RlnStateConflict("RLN storage is already owned by an active node")
                }
            }
        }

        val id = nextId++
        nodes[id] = node
        states[id] = NodeLifecycleState.CREATED
        storageDirByNodeId[id] = normalizedPath
        return id
    }

    @Synchronized
    fun get(id: Long): SdkNode {
        return nodes[id] ?: throw NodeNotFound()
    }

    @Synchronized
    fun getState(id: Long): NodeLifecycleState {
        return states[id] ?: throw NodeNotFound()
    }

    @Synchronized
    fun markInitialized(id: Long) {
        when (val state = getState(id)) {
            NodeLifecycleState.CREATED -> states[id] = NodeLifecycleState.INITIALIZED
            NodeLifecycleState.INITIALIZED -> Unit
            NodeLifecycleState.UNLOCKED,
            NodeLifecycleState.SHUTDOWN -> throw RlnStateConflict(
                "RLN init is not allowed while node is in state: $state"
            )
            NodeLifecycleState.UNLOCKING -> throw RlnStateConflict(
                "Cannot initialize RLN node while unlock is in progress"
            )
        }
    }

    @Synchronized
    fun beginUnlock(id: Long): NodeLifecycleState {
        return when (val state = getState(id)) {
            NodeLifecycleState.CREATED,
            NodeLifecycleState.INITIALIZED,
            NodeLifecycleState.SHUTDOWN -> {
                preUnlockStates[id] = state
                states[id] = NodeLifecycleState.UNLOCKING
                NodeLifecycleState.UNLOCKING
            }
            NodeLifecycleState.UNLOCKED -> NodeLifecycleState.UNLOCKED
            NodeLifecycleState.UNLOCKING -> throw RlnStateConflict("RLN unlock is already in progress")
        }
    }

    @Synchronized
    fun markUnlocked(id: Long) {
        if (states.containsKey(id)) {
            states[id] = NodeLifecycleState.UNLOCKED
            preUnlockStates.remove(id)
        }
    }

    @Synchronized
    fun markShutdown(id: Long) {
        if (states.containsKey(id)) {
            states[id] = NodeLifecycleState.SHUTDOWN
        }
    }

    @Synchronized
    fun rollbackUnlock(id: Long) {
        if (states[id] == NodeLifecycleState.UNLOCKING) {
            states[id] = preUnlockStates.remove(id) ?: NodeLifecycleState.INITIALIZED
        }
    }

    @Synchronized
    fun remove(id: Long) {
        val node = nodes.remove(id)
        val state = states.remove(id)
        preUnlockStates.remove(id)
        storageDirByNodeId.remove(id)
        if (node != null) closeNode(node, state)
    }

    private fun closeNode(node: SdkNode, state: NodeLifecycleState?) {
        try {
            if (state != NodeLifecycleState.SHUTDOWN) node.shutdown()
        } finally {
            // Releasing the UniFFI handle alone is not a node shutdown contract.
            node.close()
        }
    }

    @Synchronized
    fun createSigner(signer: NativeExternalSigner): Long {
        val id = nextSignerId++
        signers[id] = signer
        return id
    }

    @Synchronized
    fun getSigner(id: Long): NativeExternalSigner {
        return signers[id] ?: throw SignerNotFound()
    }

    @Synchronized
    fun removeSigner(id: Long) {
        val signer = signers.remove(id)
        signer?.close()
    }

    @Synchronized
    fun clearAll() {
        val nodesToClose = nodes.map { (id, node) -> node to states[id] }
        val signersToClose = signers.values.toList()
        nodes.clear()
        states.clear()
        preUnlockStates.clear()
        storageDirByNodeId.clear()
        signers.clear()
        var firstFailure: Exception? = null
        nodesToClose.forEach { (node, state) ->
            try {
                closeNode(node, state)
            } catch (error: Exception) {
                firstFailure = firstFailure ?: error
            }
        }
        signersToClose.forEach { signer ->
            try {
                signer.close()
            } catch (error: Exception) {
                firstFailure = firstFailure ?: error
            }
        }
        firstFailure?.let { throw it }
    }

    @Synchronized
    fun snapshot(): RlnNodeStoreSnapshot {
        return RlnNodeStoreSnapshot(
            nodeCount = nodes.size,
            signerCount = signers.size,
            states = states.toMap(),
            storageDirByNodeId = storageDirByNodeId.toMap()
        )
    }
}

internal class NodeNotFound : IllegalStateException("Native node handle is unavailable.")
internal class SignerNotFound : IllegalStateException("Native signer handle is unavailable.")
internal class RlnStateConflict(message: String) : IllegalStateException(message)

internal data class RlnNodeStoreSnapshot(
    val nodeCount: Int,
    val signerCount: Int,
    val states: Map<Long, RlnNodeStore.NodeLifecycleState>,
    val storageDirByNodeId: Map<Long, String>
)
