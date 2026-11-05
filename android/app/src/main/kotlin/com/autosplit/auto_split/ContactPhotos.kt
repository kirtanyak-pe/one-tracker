package com.autosplit.auto_split

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Contact photos for people you pay, read on the phone (nothing leaves it).
 * Keys are "phone:<digits>" (the number in a UPI id) or "name:<name>" (a
 * contact whose name matches exactly, and only when one contact does).
 */
object ContactPhotos {
    private val main = Handler(Looper.getMainLooper())

    /** `contactPhotos({keys})` -> {key: jpeg/png bytes}; empty without the permission. */
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val keys = call.argument<List<String>>("keys") ?: emptyList()
        val app = context.applicationContext
        if (app.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            result.success(emptyMap<String, ByteArray>())
            return
        }
        Thread {
            val out = HashMap<String, ByteArray>()
            for (k in keys.distinct().take(200)) {
                try {
                    val uri = when {
                        k.startsWith("phone:") -> byPhone(app, k.removePrefix("phone:"))
                        k.startsWith("name:") -> byName(app, k.removePrefix("name:"))
                        else -> null
                    } ?: continue
                    app.contentResolver.openInputStream(uri)?.use { out[k] = it.readBytes() }
                } catch (e: Exception) {
                    // One unreadable photo must not lose the rest.
                }
            }
            main.post { result.success(out) }
        }.start()
    }

    private fun byPhone(context: Context, digits: String): Uri? {
        if (digits.length < 10) return null
        val lookup = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(digits))
        context.contentResolver.query(
            lookup, arrayOf(ContactsContract.PhoneLookup.PHOTO_THUMBNAIL_URI), null, null, null,
        )?.use { c ->
            while (c.moveToNext()) c.getString(0)?.let { return Uri.parse(it) }
        }
        return null
    }

    private fun byName(context: Context, name: String): Uri? {
        if (name.isBlank()) return null
        context.contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(ContactsContract.Contacts.PHOTO_THUMBNAIL_URI),
            "${ContactsContract.Contacts.DISPLAY_NAME_PRIMARY} = ? COLLATE NOCASE",
            arrayOf(name.trim()),
            null,
        )?.use { c ->
            // Two "Rahul"s: no way to tell which one was paid, so no photo.
            if (c.count != 1 || !c.moveToFirst()) return null
            return c.getString(0)?.let { Uri.parse(it) }
        }
        return null
    }
}
