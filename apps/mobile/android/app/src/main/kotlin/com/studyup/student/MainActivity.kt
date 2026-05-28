package com.studyup.student

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val CHANNEL = "setudy/kiosk"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "startLockTask" -> {
          try {
            // Screen pinning / Lock task (성공 여부는 디바이스/정책에 의존)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
              startLockTask()
            }
            result.success(null)
          } catch (e: Throwable) {
            result.error("LOCK_TASK_FAILED", e.message, null)
          }
        }
        "stopLockTask" -> {
          try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
              stopLockTask()
            }
            result.success(null)
          } catch (e: Throwable) {
            result.error("UNLOCK_TASK_FAILED", e.message, null)
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}
