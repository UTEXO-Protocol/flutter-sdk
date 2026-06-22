package com.utexo.rgb_sdk_flutter

import org.utexo.rgblightningnode.NativeExternalSigner
import org.utexo.rgblightningnode.SdkNode

internal object RlnNodeStore {
    private val nodes = mutableMapOf<Long, SdkNode>()
    private val states = mutableMapOf<Long, NodeLifecycleState>()
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
                    states[existingId] = NodeLifecycleState.INITIALIZED
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
            NodeLifecycleState.INITIALIZED,
            NodeLifecycleState.UNLOCKED,
            NodeLifecycleState.SHUTDOWN -> Unit
            NodeLifecycleState.UNLOCKING -> throw IllegalStateException(
                "Cannot initialize RLN node while unlock is in progress"
            )
        }
    }

    @Synchronized
    fun beginUnlock(id: Long): NodeLifecycleState {
        return when (val state = getState(id)) {
            NodeLifecycleState.INITIALIZED,
            NodeLifecycleState.SHUTDOWN -> {
                states[id] = NodeLifecycleState.UNLOCKING
                NodeLifecycleState.UNLOCKING
            }
            NodeLifecycleState.UNLOCKED -> NodeLifecycleState.UNLOCKED
            NodeLifecycleState.UNLOCKING -> throw IllegalStateException("RLN unlock is already in progress")
            NodeLifecycleState.CREATED -> throw IllegalStateException("RLN node must be initialized before unlock")
        }
    }

    @Synchronized
    fun markUnlocked(id: Long) {
        if (states.containsKey(id)) {
            states[id] = NodeLifecycleState.UNLOCKED
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
            states[id] = NodeLifecycleState.INITIALIZED
        }
    }

    @Synchronized
    fun remove(id: Long) {
        nodes.remove(id)?.close()
        states.remove(id)
        storageDirByNodeId.remove(id)
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
        signers.remove(id)
    }
}
