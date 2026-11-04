package com.autosplit.auto_split

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import java.net.URLEncoder

/**
 * Opens Splitwise's "Add expense" screen with the payment filled in. Splitwise
 * routes https://secure.splitwise.com/applinks/... to itself; setPackage is
 * required, otherwise the browser takes it. It reads amount, currency_code,
 * description, category_id, group_id and friend_id (no date).
 */
object SplitwiseLauncher {
    const val PACKAGE = "com.Splitwise.SplitwiseMobile"
    private const val BASE = "https://secure.splitwise.com/applinks/expenses/new"
    private const val MAX_DESCRIPTION = 100

    /** Plain decimal rupees: 45000 -> "450", 45050 -> "450.50". */
    fun amountText(amountMinor: Long): String {
        val minor = Math.abs(amountMinor)
        val paise = (minor % 100).toInt()
        return if (paise == 0) "${minor / 100}" else "${minor / 100}.${paise.toString().padStart(2, '0')}"
    }

    /** The link Splitwise handles; description is percent-encoded (spaces as %20). */
    fun url(amountMinor: Long, payee: String, groupId: Long? = null): String {
        val description = URLEncoder.encode(payee.trim().take(MAX_DESCRIPTION), "UTF-8").replace("+", "%20")
        val group = if (groupId != null && groupId > 0) "&group_id=$groupId" else ""
        return "$BASE?description=$description&amount=${amountText(amountMinor)}&currency_code=INR$group"
    }

    /** True if Splitwise opened; otherwise its Play Store page is opened instead. */
    fun open(context: Context, amountMinor: Long, payee: String, groupId: Long? = null): Boolean {
        val link = Intent(Intent.ACTION_VIEW, Uri.parse(url(amountMinor, payee, groupId)))
            .setPackage(PACKAGE)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(link)
            return true
        } catch (e: ActivityNotFoundException) {
            // Not installed (or too old to know the link): offer it in the store.
        }
        for (store in listOf("market://details?id=$PACKAGE", "https://play.google.com/store/apps/details?id=$PACKAGE")) {
            try {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(store)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                break
            } catch (e: ActivityNotFoundException) {
                // try the next one
            }
        }
        return false
    }
}
