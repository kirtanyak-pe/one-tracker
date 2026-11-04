package com.autosplit.auto_split

import android.app.Activity
import android.os.Bundle

/**
 * No-UI landing for the notification's tap / Split: records the choice,
 * clears the notification and opens Splitwise, then finishes. It is the
 * PendingIntent's own target, so it isn't a notification trampoline.
 */
class SplitActionActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val txnId = intent.getStringExtra(SplitNotifications.EXTRA_TXN)
        if (txnId != null) {
            SplitPending.add(this, txnId, SplitNotifications.ACTION_SPLIT)
            SplitNotifications.cancel(this, txnId)
            SplitwiseLauncher.open(
                this,
                intent.getLongExtra(SplitNotifications.EXTRA_AMOUNT, 0L),
                intent.getStringExtra(SplitNotifications.EXTRA_PAYEE) ?: "",
                intent.getLongExtra(SplitNotifications.EXTRA_GROUP, -1L).takeIf { it > 0 },
            )
        }
        finish()
    }
}
