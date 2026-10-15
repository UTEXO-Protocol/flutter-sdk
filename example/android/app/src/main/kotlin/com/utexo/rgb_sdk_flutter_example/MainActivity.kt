package com.utexo.rgb_sdk_flutter_example

import io.flutter.embedding.android.FlutterActivity
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.utexo.rgb_sdk_flutter_example/permissions").setMethodCallHandler { call, result ->
            if (call.method != "requestLocalNetworkPermission") {
                result.notImplemented()
            } else if (Build.VERSION.SDK_INT < 37 || applicationInfo.targetSdkVersion < 37 ||
                checkSelfPermission(LOCAL_NETWORK) == PackageManager.PERMISSION_GRANTED) {
                result.success(true)
            } else if (permissionResult != null) {
                result.error("permission_request_active", "A permission request is active.", null)
            } else {
                permissionResult = result
                requestPermissions(arrayOf(LOCAL_NETWORK), LOCAL_NETWORK_REQUEST)
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != LOCAL_NETWORK_REQUEST) return
        val result = permissionResult
        permissionResult = null
        result?.success(grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED })
    }

    override fun onDestroy() {
        permissionResult?.error("activity_destroyed", "Permission request was interrupted.", null)
        permissionResult = null
        super.onDestroy()
    }

    companion object {
        private const val LOCAL_NETWORK = "android.permission.ACCESS_LOCAL_NETWORK"
        private const val LOCAL_NETWORK_REQUEST = 29471
    }
}
