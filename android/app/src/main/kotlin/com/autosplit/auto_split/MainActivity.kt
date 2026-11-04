package com.autosplit.auto_split

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "auto_spend/sms"

        /** The app's engine while it's running; SmsReceiver hands SMS to it. */
        @Volatile
        var liveEngine: FlutterEngine? = null
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (liveEngine === flutterEngine) liveEngine = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        liveEngine = flutterEngine
        // The Splitwise API key (removed in 1.4) lived in these; make sure none is left.
        deleteSharedPreferences("FlutterSecureStorage")
        deleteSharedPreferences("FlutterSecureStorageConfiguration")
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "inbox" -> {
                        val since = (call.argument<Number>("since") ?: 0).toLong()
                        val limit = call.argument<Int>("limit") ?: 3000
                        // Off the UI thread: a big inbox can take a moment.
                        Thread {
                            try {
                                val rows = readInbox(since, limit)
                                runOnUiThread { result.success(rows) }
                            } catch (e: SecurityException) {
                                runOnUiThread { result.error("permission", e.message, null) }
                            } catch (e: Exception) {
                                runOnUiThread { result.error("read_failed", e.message, null) }
                            }
                        }.start()
                    }
                    "deviceClass" -> {
                        // For lite mode on low-end phones.
                        val am = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
                        val mem = android.app.ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
                        result.success(
                            mapOf(
                                "lowRam" to am.isLowRamDevice,
                                "totalMemMb" to (mem.totalMem / (1024 * 1024)).toInt(),
                                "cores" to Runtime.getRuntime().availableProcessors(),
                            ),
                        )
                    }
                    "smsPermissions" -> {
                        fun has(p: String) = checkSelfPermission(p) == android.content.pm.PackageManager.PERMISSION_GRANTED
                        result.success(
                            mapOf(
                                "read" to has(android.Manifest.permission.READ_SMS),
                                "receive" to has(android.Manifest.permission.RECEIVE_SMS),
                            ),
                        )
                    }
                    "pinWidget" -> {
                        // Shows the launcher's own "Add widget?" confirmation.
                        val manager = android.appwidget.AppWidgetManager.getInstance(this)
                        val supported = android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O &&
                            manager.isRequestPinAppWidgetSupported
                        if (supported) {
                            manager.requestPinAppWidget(
                                android.content.ComponentName(this, SpendWidgetProvider::class.java), null, null,
                            )
                        }
                        result.success(supported)
                    }
                    "widget" -> {
                        SpendWidgetProvider.update(this, call.argument<String>("json") ?: "{}")
                        result.success(null)
                    }
                    else -> if (!SplitChannel.handle(this, call, result)) result.notImplemented()
                }
            }
    }

    /** SMS from alphanumeric senders (banks, "VM-HDFCBK") newer than [since]. */
    private fun readInbox(since: Long, limit: Int): List<Map<String, Any?>> {
        val rows = mutableListOf<Map<String, Any?>>()
        contentResolver.query(
            Uri.parse("content://sms/inbox"),
            arrayOf("_id", "address", "body", "date"),
            "date > ?",
            arrayOf(since.toString()),
            "date DESC",
        )?.use { c ->
            val id = c.getColumnIndexOrThrow("_id")
            val address = c.getColumnIndexOrThrow("address")
            val body = c.getColumnIndexOrThrow("body")
            val date = c.getColumnIndexOrThrow("date")
            while (c.moveToNext() && rows.size < limit) {
                val sender = c.getString(address) ?: continue
                // Personal numbers can't be bank alerts; skip them unread.
                if (!sender.any { it.isLetter() }) continue
                rows.add(
                    mapOf(
                        "id" to c.getLong(id).toString(),
                        "sender" to sender,
                        "body" to c.getString(body),
                        "date" to c.getLong(date),
                    )
                )
            }
        }
        return rows
    }
}
