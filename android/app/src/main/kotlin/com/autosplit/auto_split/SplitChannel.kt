package com.autosplit.auto_split

import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** The Splitwise methods of the app's channel, shared by the UI and background engines. */
object SplitChannel {
    /** True if [call] was one of ours (and has been answered). */
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result): Boolean {
        fun amount() = (call.argument<Number>("amountMinor") ?: 0).toLong()
        fun payee() = call.argument<String>("payee") ?: ""
        fun group() = call.argument<Number>("groupId")?.toLong()
        when (call.method) {
            "showSplitNotification" -> {
                val txnId = call.argument<String>("txnId")
                if (txnId == null) {
                    result.error("bad_args", "txnId missing", null)
                } else {
                    SplitNotifications.show(context, txnId, amount(), payee(), group())
                    result.success(null)
                }
            }
            "openSplitwise" -> result.success(SplitwiseLauncher.open(context, amount(), payee(), group()))
            "takePendingSplitActions" -> result.success(SplitPending.take(context))
            "appIcons" -> AppIcons.handle(context, call, result)
            "contactIndex", "contactPhotos" -> ContactPhotos.handle(context, call, result)
            else -> return false
        }
        return true
    }
}
