package com.finman.finman_engine

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Telephony

/**
 * Real-time SMS capture. Reassembles the multipart message parts (doc 07 §11) and forwards a single
 * body to Dart via the MethodChannel while the app/engine is alive; otherwise the launch catch-up
 * sweep (MainActivity.querySweep) picks it up next time. Raw text never leaves the device.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val msgs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT)
            Telephony.Sms.Intents.getMessagesFromIntent(intent) else return
        if (msgs.isNullOrEmpty()) return

        // reassemble multipart parts (same originating address) into one body
        val sender = msgs[0].originatingAddress ?: ""
        val body = StringBuilder()
        for (m in msgs) body.append(m.messageBody ?: "")
        val timeMs = msgs[0].timestampMillis

        MainActivity.channel?.invokeMethod(
            "onSms",
            mapOf(
                "messageId" to "rt-$timeMs-${sender.hashCode()}",
                "sender" to sender,
                "body" to body.toString(),
                "timeMs" to timeMs
            )
        )
    }
}
