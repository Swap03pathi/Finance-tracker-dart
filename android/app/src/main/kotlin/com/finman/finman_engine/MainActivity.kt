package com.finman.finman_engine

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Native bridge for SMS (doc 03 §2). MethodChannel "finman/sms":
 *   - requestPermission: ask for READ_SMS/RECEIVE_SMS at runtime, return whether already granted.
 *   - querySweep(sinceMs): the launch catch-up scan of the inbox (handles app-was-killed).
 * Real-time delivery is pushed by SmsReceiver via [channel] while the engine is alive.
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "finman/sms"
        @JvmStatic
        var channel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel = ch
        ch.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    val granted = hasSmsPermission()
                    if (!granted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        requestPermissions(
                            arrayOf(Manifest.permission.READ_SMS, Manifest.permission.RECEIVE_SMS), 1
                        )
                    }
                    result.success(granted)
                }
                "querySweep" -> {
                    val sinceMs = (call.argument<Number>("sinceMs"))?.toLong() ?: 0L
                    result.success(querySweep(sinceMs))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasSmsPermission(): Boolean =
        checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED

    /** Catch-up scan: every inbox SMS newer than the last-processed checkpoint. */
    private fun querySweep(sinceMs: Long): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!hasSmsPermission()) return out
        val uri = Uri.parse("content://sms/inbox")
        val cols = arrayOf("_id", "address", "body", "date")
        contentResolver.query(uri, cols, "date > ?", arrayOf(sinceMs.toString()), "date ASC")?.use { c ->
            val idI = c.getColumnIndex("_id")
            val addrI = c.getColumnIndex("address")
            val bodyI = c.getColumnIndex("body")
            val dateI = c.getColumnIndex("date")
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "messageId" to c.getString(idI),
                        "sender" to (c.getString(addrI) ?: ""),
                        "body" to (c.getString(bodyI) ?: ""),
                        "timeMs" to c.getLong(dateI)
                    )
                )
            }
        }
        return out
    }
}
