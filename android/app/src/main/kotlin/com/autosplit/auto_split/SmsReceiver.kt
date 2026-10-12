package com.autosplit.auto_split

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Wakes up for every incoming SMS — even when Auto Spend isn't running —
 * so a bank debit can pop the split card the moment it arrives.
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (parts.isEmpty()) return
        val sender = parts[0].originatingAddress ?: return
        // Banks send from names ("VM-HDFCBK"), never from phone numbers.
        if (!sender.any { it.isLetter() }) return
        val body = parts.joinToString("") { it.messageBody ?: "" }
        IncomingSms.handle(context, sender, body, parts[0].timestampMillis, goAsync())
    }
}

/** Shared by the real receiver and [TestSmsReceiver]. */
internal object IncomingSms {
    private val DEBIT = Regex("(?i)\\b(debited|spent|paid|sent|withdrawn|purchase|txn|dr)\\b")
    private const val TIMEOUT_MS = 25_000L

    fun handle(context: Context, sender: String, body: String, at: Long, pending: BroadcastReceiver.PendingResult) {
        if (!DEBIT.containsMatchIn(body)) {
            pending.finish()
            return
        }

        // App already running: hand it over, it knows if you're looking at it.
        MainActivity.liveEngine?.let { engine ->
            Handler(Looper.getMainLooper()).post {
                MethodChannel(engine.dartExecutor.binaryMessenger, MainActivity.CHANNEL)
                    .invokeMethod("incoming", mapOf("sender" to sender, "body" to body, "at" to at))
                pending.finish()
            }
            return
        }

        // Not running: start a short-lived background engine to handle it.
        val app = context.applicationContext
        Handler(Looper.getMainLooper()).post {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(app)
            loader.ensureInitializationComplete(app, null)
            val engine = FlutterEngine(app)
            var finished = false
            fun finish() {
                if (finished) return
                finished = true
                engine.destroy()
                pending.finish()
            }
            MethodChannel(engine.dartExecutor.binaryMessenger, MainActivity.CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        // Widget refresh from the background isolate.
                        "widget" -> {
                            SpendWidgetProvider.update(app, call.argument<String>("json") ?: "{}")
                            result.success(null)
                        }
                        "done" -> {
                            result.success(null)
                            finish()
                        }
                        else -> result.notImplemented()
                    }
                }
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "smsMain"),
                listOf(sender, body, at.toString(), app.resources.displayMetrics.density.toString()),
            )
            Handler(Looper.getMainLooper()).postDelayed({ finish() }, TIMEOUT_MS)
        }
    }
}

/**
 * Feeds a fake bank SMS through the same path, for testing on a real phone:
 *   adb shell am broadcast -n com.autosplit.auto_split/.TestSmsReceiver \
 *     -a com.autosplit.auto_split.TEST_SMS --es sender VM-HDFCBK --es body "Rs.450 debited…"
 * Guarded by the DUMP permission, which only the adb shell holds.
 */
class TestSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val sender = intent.getStringExtra("sender") ?: return
        val body = intent.getStringExtra("body") ?: return
        IncomingSms.handle(context, sender, body, System.currentTimeMillis(), goAsync())
    }
}
