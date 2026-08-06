package com.utexo.rgb_sdk_flutter

import org.utexo.rgblightningnode.NativeExternalSigner
import org.utexo.rgblightningnode.SdkNode

internal object RlnNodeStore {
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
    fun create(node: SdkNode, storageDirPath: String): Long {
        val normalizedPath = storageDirPath.trim()
        if (normalizedPath.isNotEmpty()) {
            val existingId = storageDirByNodeId.entries.firstOrNull { it.value == normalizedPath }?.key
            if (existingId != null) {
                if (states[existingId] == NodeLifecycleState.SHUTDOWN) {
                    nodes[existingId]?.close()
                    nodes[existingId] = node
                    states[existingId] = NodeLifecycleState.CREATED
                    return existingId
                }

                throw IllegalStateException("RLN node already exists for storageDirPath: $normalizedPath")
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
        return nodes[id] ?: throw IllegalStateException("RLN node with id $id not found")
    }

    @Synchronized
    fun getState(id: Long): NodeLifecycleState {
        return states[id] ?: throw IllegalStateException("RLN node with id $id not found")
    }

    @Synchronized
    fun markInitialized(id: Long) {
        when (val state = getState(id)) {
            NodeLifecycleState.CREATED -> states[id] = NodeLifecycleState.INITIALIZED
            NodeLifecycleState.INITIALIZED -> Unit
            NodeLifecycleState.UNLOCKED,
            NodeLifecycleState.SHUTDOWN -> throw IllegalStateException(
                "RLN init is not allowed while node is in state: $state"
            )
            NodeLifecycleState.UNLOCKING -> throw IllegalStateException(
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
            NodeLifecycleState.UNLOCKING -> throw IllegalStateException("RLN unlock is already in progress")
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
        states.remove(id)
        preUnlockStates.remove(id)
        storageDirByNodeId.remove(id)
        node?.close()
    }

    @Synchronized
    fun createSigner(signer: NativeExternalSigner): Long {
        val id = nextSignerId++
        signers[id] = signer
        return id
    }

    @Synchronized
    fun getSigner(id: Long): NativeExternalSigner {
        return signers[id] ?: throw IllegalStateException("Native signer with id $id not found")
    }

    @Synchronized
    fun removeSigner(id: Long) {
        val signer = signers.remove(id)
        signer?.close()
    }

    @Synchronized
    fun clearAll() {
        val nodesToClose = nodes.values.toList()
        val signersToClose = signers.values.toList()
        nodes.clear()
        states.clear()
        preUnlockStates.clear()
        storageDirByNodeId.clear()
        signers.clear()
        var firstFailure: RuntimeException? = null
        nodesToClose.forEach { node ->
            try {
                node.close()
            } catch (error: RuntimeException) {
                firstFailure = firstFailure ?: error
            }
        }
        signersToClose.forEach { signer ->
            try {
                signer.close()
            } catch (error: RuntimeException) {
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

internal data class RlnNodeStoreSnapshot(
    val nodeCount: Int,
    val signerCount: Int,
    val states: Map<Long, RlnNodeStore.NodeLifecycleState>,
    val storageDirByNodeId: Map<Long, String>
)
