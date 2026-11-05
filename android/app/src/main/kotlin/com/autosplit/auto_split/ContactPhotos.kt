package com.autosplit.auto_split

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Contact photos for people you pay, read on the phone (nothing leaves it).
 * `contactIndex` lists contacts that have a photo (id, name, numbers) so Dart
 * can match payees; `contactPhotos({ids})` returns the thumbnails.
 */
object ContactPhotos {
    private val main = Handler(Looper.getMainLooper())

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val app = context.applicationContext
        if (app.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
            result.success(if (call.method == "contactIndex") emptyList<Any>() else emptyMap<Long, ByteArray>())
            return
        }
        Thread {
            val out: Any = try {
                if (call.method == "contactIndex") index(app) else photos(app, call)
            } catch (e: Exception) {
                if (call.method == "contactIndex") emptyList<Any>() else emptyMap<Long, ByteArray>()
            }
            main.post { result.success(out) }
        }.start()
    }

    private fun index(context: Context): List<Map<String, Any>> {
        val names = HashMap<Long, String>()
        context.contentResolver.query(
            ContactsContract.Contacts.CONTENT_URI,
            arrayOf(ContactsContract.Contacts._ID, ContactsContract.Contacts.DISPLAY_NAME_PRIMARY),
            "${ContactsContract.Contacts.PHOTO_THUMBNAIL_URI} IS NOT NULL",
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) names[c.getLong(0)] = c.getString(1) ?: ""
        }
        val phones = HashMap<Long, MutableList<String>>()
        context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Phone.CONTACT_ID, ContactsContract.CommonDataKinds.Phone.NUMBER),
            null,
            null,
            null,
        )?.use { c ->
            while (c.moveToNext()) {
                val id = c.getLong(0)
                if (id !in names) continue
                val digits = (c.getString(1) ?: "").filter { it.isDigit() }
                if (digits.length >= 10) phones.getOrPut(id) { mutableListOf() }.add(digits.takeLast(10))
            }
        }
        return names.map { (id, name) -> mapOf("id" to id, "name" to name, "phones" to (phones[id] ?: emptyList<String>())) }
    }

    private fun photos(context: Context, call: MethodCall): Map<Long, ByteArray> {
        val ids = (call.argument<List<Number>>("ids") ?: emptyList()).map { it.toLong() }.distinct().take(200)
        val out = HashMap<Long, ByteArray>()
        for (id in ids) {
            try {
                val contact = ContentUris.withAppendedId(ContactsContract.Contacts.CONTENT_URI, id)
                ContactsContract.Contacts.openContactPhotoInputStream(context.contentResolver, contact, false)
                    ?.use { out[id] = it.readBytes() }
            } catch (e: Exception) {
                // One unreadable photo must not lose the rest.
            }
        }
        return out
    }
}
