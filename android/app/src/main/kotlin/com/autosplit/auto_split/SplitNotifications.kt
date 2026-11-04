package com.autosplit.auto_split

import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationChannelCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * The "split it?" notification. Tap or Split -> [SplitActionActivity] (records
 * it, opens Splitwise); Skip / Not expense -> [SplitActionReceiver]. Neither
 * goes through the app, so it works while One Tracker is closed.
 */
object SplitNotifications {
    const val CHANNEL = "split"
    const val ACTION_SPLIT = "split"
    const val ACTION_SKIP = "skip"
    const val ACTION_NOT_EXPENSE = "notExpense"

    const val EXTRA_TXN = "txnId"
    const val EXTRA_AMOUNT = "amountMinor"
    const val EXTRA_PAYEE = "payee"
    const val EXTRA_GROUP = "groupId"

    private const val TIMEOUT_MS = 24L * 60 * 60 * 1000

    /** One notification per payment: showing it again replaces it. */
    fun idFor(txnId: String): Int = txnId.hashCode() and 0x7fffffff

    /** "₹450" / "₹1,25,000.50": Indian digit grouping. */
    fun rupees(amountMinor: Long): String {
        val text = SplitwiseLauncher.amountText(amountMinor)
        val whole = text.substringBefore('.')
        val fraction = text.substringAfter('.', "")
        val last3 = whole.takeLast(3)
        val rest = whole.dropLast(3).reversed().chunked(2).joinToString(",").reversed()
        val grouped = if (rest.isEmpty()) last3 else "$rest,$last3"
        return "₹" + grouped + if (fraction.isEmpty()) "" else ".$fraction"
    }

    fun title(amountMinor: Long, payee: String): String = "${rupees(amountMinor)} · $payee"

    fun show(context: Context, txnId: String, amountMinor: Long, payee: String, groupId: Long?) {
        val manager = NotificationManagerCompat.from(context)
        manager.createNotificationChannel(
            NotificationChannelCompat.Builder(CHANNEL, NotificationManagerCompat.IMPORTANCE_HIGH)
                .setName("Split suggestions")
                .setDescription("Offers to split a payment in Splitwise")
                .setShowBadge(false)
                .build(),
        )
        val id = idFor(txnId)
        val split = activityIntent(context, ACTION_SPLIT, txnId, amountMinor, payee, groupId, id)
        val skip = receiverIntent(context, ACTION_SKIP, txnId, id)
        val notExpense = receiverIntent(context, ACTION_NOT_EXPENSE, txnId, id)

        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_split)
            .setContentTitle(title(amountMinor, payee))
            .setContentText("Tap to split it in Splitwise")
            .setContentIntent(split)
            .setAutoCancel(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_RECOMMENDATION)
            .setTimeoutAfter(TIMEOUT_MS)
            .addAction(R.drawable.ic_stat_split, "Split", split)
            .addAction(R.drawable.ic_stat_split, "Skip", skip)
            .addAction(R.drawable.ic_stat_split, "Not expense", notExpense)
            .build()
        try {
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            // Notifications switched off (Android 13+): nothing to show.
        }
    }

    fun cancel(context: Context, txnId: String) {
        NotificationManagerCompat.from(context).cancel(idFor(txnId))
    }

    /** Request codes are unique per payment and action (actions get slots 0-2). */
    private fun requestCode(id: Int, slot: Int) = (id and 0x1fffffff) * 4 + slot

    private fun slotOf(action: String) = when (action) {
        ACTION_SPLIT -> 0
        ACTION_SKIP -> 1
        else -> 2
    }

    private fun activityIntent(
        context: Context, action: String, txnId: String, amountMinor: Long, payee: String, groupId: Long?, id: Int,
    ): PendingIntent {
        val intent = Intent(context, SplitActionActivity::class.java)
            .setAction("com.autosplit.auto_split.$action.$txnId")
            .putExtra(EXTRA_TXN, txnId)
            .putExtra("action", action)
            .putExtra(EXTRA_AMOUNT, amountMinor)
            .putExtra(EXTRA_PAYEE, payee)
            .putExtra(EXTRA_GROUP, groupId ?: -1L)
        return PendingIntent.getActivity(
            context, requestCode(id, slotOf(action)), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun receiverIntent(context: Context, action: String, txnId: String, id: Int): PendingIntent {
        val intent = Intent(context, SplitActionReceiver::class.java)
            .setAction("com.autosplit.auto_split.$action.$txnId")
            .putExtra(EXTRA_TXN, txnId)
            .putExtra("action", action)
        return PendingIntent.getBroadcast(
            context, requestCode(id, slotOf(action)), intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/** Actions from the notification wait here until the app next starts or resumes. */
object SplitPending {
    private const val FILE = "split_actions"
    private const val KEY = "pending"

    @Synchronized
    fun add(context: Context, txnId: String, action: String) {
        val prefs = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val list = org.json.JSONArray(prefs.getString(KEY, "[]") ?: "[]")
        list.put(
            org.json.JSONObject().put("txnId", txnId).put("action", action).put("at", System.currentTimeMillis()),
        )
        prefs.edit().putString(KEY, list.toString()).commit()
    }

    /** Everything queued, oldest first; the queue is emptied. */
    @Synchronized
    fun take(context: Context): List<Map<String, Any>> {
        val prefs = context.applicationContext.getSharedPreferences(FILE, Context.MODE_PRIVATE)
        val list = org.json.JSONArray(prefs.getString(KEY, "[]") ?: "[]")
        prefs.edit().remove(KEY).commit()
        return (0 until list.length()).map { i ->
            val o = list.getJSONObject(i)
            mapOf("txnId" to o.getString("txnId"), "action" to o.getString("action"), "at" to o.getLong("at"))
        }
    }
}
