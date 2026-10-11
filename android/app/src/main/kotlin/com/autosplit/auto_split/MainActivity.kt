package com.autosplit.auto_split

import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "auto_spend/sms")
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
                    else -> result.notImplemented()
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
