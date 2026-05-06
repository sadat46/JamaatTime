package com.sadat.jamaattime

import android.content.Intent
import android.view.WindowManager
import com.sadat.jamaattime.autovibration.AutoVibrationPlugin
import com.sadat.jamaattime.familysafety.FamilySafetyChannel
import com.sadat.jamaattime.focusguard.FocusGuardChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "jamaat_time/screen_awake"
    private var familySafetyChannel: FamilySafetyChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    runOnUiThread {
                        if (enabled) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        FocusGuardChannel(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        BatteryOptimizationChannel(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        AutoVibrationPlugin(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        familySafetyChannel = FamilySafetyChannel(flutterEngine.dartExecutor.binaryMessenger, this)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (familySafetyChannel?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
