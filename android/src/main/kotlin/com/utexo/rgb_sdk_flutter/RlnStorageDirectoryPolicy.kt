package com.utexo.rgb_sdk_flutter

import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import java.io.File
import java.util.ArrayDeque

internal class RlnStorageDirectoryPolicyException(message: String) : Exception(message)

internal data class RlnStorageDirectoryMetadata(
    val isDirectory: Boolean,
    val ownerId: Int,
    val permissions: Int
)

internal interface RlnStorageDirectoryAccess {
    val effectiveUserId: Int

    fun createOwnerOnlyDirectories(path: String)

    fun metadata(path: String): RlnStorageDirectoryMetadata
}

internal class RlnStorageDirectoryPolicy(
    private val access: RlnStorageDirectoryAccess = AndroidRlnStorageDirectoryAccess
) {
    fun prepare(path: String) {
        if (path.isBlank()) {
            fail("storageDirPath must not be empty.")
        }
        if (!File(path).isAbsolute) {
            fail("storageDirPath must be an absolute path.")
        }
        if (path.split('/').any { it == "." || it == ".." }) {
            fail("storageDirPath must not contain '.' or '..' components.")
        }

        access.createOwnerOnlyDirectories(path)
        val metadata = access.metadata(path)
        if (!metadata.isDirectory) {
            fail("storageDirPath must identify a directory, not a file or symbolic link.")
        }
        if (metadata.ownerId != access.effectiveUserId) {
            fail(
                "storageDirPath must be owned by the current process user; " +
                    "found uid ${metadata.ownerId}, expected ${access.effectiveUserId}."
            )
        }
        if (metadata.permissions != OWNER_ONLY_PERMISSIONS) {
            fail(
                "storageDirPath must have mode 0700; " +
                    "found mode ${metadata.permissions.toString(8)}."
            )
        }
    }

    private fun fail(message: String): Nothing {
        throw RlnStorageDirectoryPolicyException(message)
    }

    private companion object {
        const val OWNER_ONLY_PERMISSIONS = 0x1C0
    }
}

private object AndroidRlnStorageDirectoryAccess : RlnStorageDirectoryAccess {
    override val effectiveUserId: Int
        get() = Os.geteuid()

    override fun createOwnerOnlyDirectories(path: String) {
        val missingDirectories = ArrayDeque<File>()
        var current: File? = File(path)

        while (current != null) {
            val metadata = metadataOrNull(current.path)
            if (metadata != null) {
                if (!metadata.isDirectory) {
                    throw RlnStorageDirectoryPolicyException(
                        "storageDirPath has a non-directory path component."
                    )
                }
                break
            }
            missingDirectories.addFirst(current)
            current = current.parentFile
        }

        if (current == null) {
            throw RlnStorageDirectoryPolicyException(
                "storageDirPath has no existing directory ancestor."
            )
        }

        for (directory in missingDirectories) {
            try {
                Os.mkdir(directory.path, OWNER_ONLY_PERMISSIONS)
            } catch (error: ErrnoException) {
                if (error.errno != OsConstants.EEXIST) {
                    throw RlnStorageDirectoryPolicyException(
                        "storageDirPath could not be created: ${error.message}"
                    )
                }
            }

            val metadata = metadata(directory.path)
            if (!metadata.isDirectory) {
                throw RlnStorageDirectoryPolicyException(
                    "storageDirPath has a non-directory path component."
                )
            }
            if (metadata.ownerId != effectiveUserId) {
                throw RlnStorageDirectoryPolicyException(
                    "storageDirPath has a path component not owned by the current process user."
                )
            }
            if (metadata.permissions != OWNER_ONLY_PERMISSIONS) {
                throw RlnStorageDirectoryPolicyException(
                    "storageDirPath has a newly created component without mode 0700."
                )
            }
        }
    }

    override fun metadata(path: String): RlnStorageDirectoryMetadata {
        val status = try {
            Os.lstat(path)
        } catch (error: ErrnoException) {
            throw RlnStorageDirectoryPolicyException(
                "storageDirPath could not be inspected: ${error.message}"
            )
        }
        return metadataFromStatus(status)
    }

    private fun metadataFromStatus(
        status: android.system.StructStat
    ): RlnStorageDirectoryMetadata {
        return RlnStorageDirectoryMetadata(
            isDirectory = status.st_mode and OsConstants.S_IFMT == OsConstants.S_IFDIR,
            ownerId = status.st_uid,
            permissions = status.st_mode and 0x1FF
        )
    }

    private fun metadataOrNull(path: String): RlnStorageDirectoryMetadata? {
        return try {
            metadataFromStatus(Os.lstat(path))
        } catch (error: ErrnoException) {
            if (error.errno == OsConstants.ENOENT) {
                null
            } else {
                throw RlnStorageDirectoryPolicyException(
                    "storageDirPath could not be inspected: ${error.message}"
                )
            }
        }
    }

    private const val OWNER_ONLY_PERMISSIONS = 0x1C0
    private const val GROUP_AND_OTHER_MASK = 0x3F
}
