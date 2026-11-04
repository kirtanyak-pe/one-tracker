package com.autosplit.auto_split

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** The notification's Skip and Not expense buttons: record it and dismiss. */
class SplitActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val txnId = intent.getStringExtra(SplitNotifications.EXTRA_TXN) ?: return
        val action = intent.getStringExtra("action") ?: return
        if (action != SplitNotifications.ACTION_SKIP && action != SplitNotifications.ACTION_NOT_EXPENSE) return
        SplitPending.add(context, txnId, action)
        SplitNotifications.cancel(context, txnId)
    }
}
