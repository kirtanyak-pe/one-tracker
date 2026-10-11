package com.autosplit.auto_split

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.text.format.DateUtils
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * Home-screen spending summary. The app pushes today/week/month figures
 * (see lib/sources/widget_bridge.dart); the Today | Week | Month toggle is
 * handled here, so switching is instant and doesn't open the app.
 */
class SpendWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val PREFS = "auto_spend_widget"
        private const val KEY_DATA = "data"
        private const val ACTION_PERIOD = "com.autosplit.auto_split.widget.PERIOD"
        private const val EXTRA_PERIOD = "period"
        private val PERIODS = listOf("today", "week", "month")

        /** Saves fresh figures from the app and redraws every placed widget. */
        fun update(context: Context, json: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_DATA, json).apply()
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, SpendWidgetProvider::class.java))
            for (id in ids) render(context, manager, id)
        }

        private fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val period = prefs.getString("period_$id", "month") ?: "month"
            val views = RemoteViews(context.packageName, R.layout.spend_widget)

            val data = prefs.getString(KEY_DATA, null)?.let { runCatching { JSONObject(it) }.getOrNull() }
            val p = data?.optJSONObject("periods")?.optJSONObject(period)
            val stale = p == null || System.currentTimeMillis() >= p.optLong("validUntil", 0)

            views.setTextViewText(R.id.widget_title, p?.optString("title") ?: "Auto Spend")
            views.setTextViewText(R.id.widget_amount, if (stale) "—" else p!!.optString("amount"))
            views.setTextViewText(
                R.id.widget_caption,
                when {
                    p == null -> "Open Auto Spend to set up"
                    stale -> "Open Auto Spend to refresh"
                    else -> p.optString("caption")
                },
            )
            val updated = data?.optLong("updatedAt", 0) ?: 0
            views.setTextViewText(
                R.id.widget_updated,
                if (updated == 0L) "" else DateUtils.getRelativeTimeSpanString(
                    updated, System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS,
                    DateUtils.FORMAT_ABBREV_RELATIVE,
                ),
            )

            // Budget meter (month only): ink → accent at 80% → error over.
            val meters = listOf(R.id.widget_meter_ok, R.id.widget_meter_warn, R.id.widget_meter_over)
            meters.forEach { views.setViewVisibility(it, View.GONE) }
            if (!stale && p != null && !p.isNull("meter")) {
                val use = p.optDouble("meter", 0.0)
                val bar = when {
                    use >= 1.0 -> R.id.widget_meter_over
                    use >= 0.8 -> R.id.widget_meter_warn
                    else -> R.id.widget_meter_ok
                }
                views.setViewVisibility(bar, View.VISIBLE)
                views.setProgressBar(bar, 100, (use.coerceIn(0.0, 1.0) * 100).toInt(), false)
            }

            // Segments: white pill on the selected one.
            val segments = mapOf(
                "today" to R.id.widget_seg_today,
                "week" to R.id.widget_seg_week,
                "month" to R.id.widget_seg_month,
            )
            for ((index, name) in PERIODS.withIndex()) {
                val view = segments.getValue(name)
                val on = name == period
                views.setInt(view, "setBackgroundResource", if (on) R.drawable.widget_seg_on else 0)
                setColor(context, views, view, if (on) R.color.widget_ink else R.color.widget_muted)
                val toggle = Intent(context, SpendWidgetProvider::class.java)
                    .setAction(ACTION_PERIOD)
                    .putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                    .putExtra(EXTRA_PERIOD, name)
                views.setOnClickPendingIntent(
                    view,
                    PendingIntent.getBroadcast(
                        context, id * 10 + index, toggle,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                    ),
                )
            }

            // Tapping the figures opens the app (which rescans and refreshes us).
            val open = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            views.setOnClickPendingIntent(
                R.id.widget_body,
                PendingIntent.getActivity(context, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE),
            )

            manager.updateAppWidget(id, views)
        }

        /** Text colour that follows light/dark mode on Android 12+. */
        private fun setColor(context: Context, views: RemoteViews, view: Int, color: Int) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColorStateList(view, "setTextColor", color)
            } else {
                views.setTextColor(view, context.getColor(color))
            }
        }
    }

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) render(context, manager, id)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_PERIOD) return
        val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        val period = intent.getStringExtra(EXTRA_PERIOD) ?: return
        if (id == AppWidgetManager.INVALID_APPWIDGET_ID || period !in PERIODS) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("period_$id", period).apply()
        render(context, AppWidgetManager.getInstance(context), id)
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val edit = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
        for (id in ids) edit.remove("period_$id")
        edit.apply()
    }
}
