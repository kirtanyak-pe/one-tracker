package com.autosplit.auto_split

import android.app.Activity
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Backup files through Android's own file picker (Storage Access Framework),
 * so the user chooses the place and the app needs no storage permission.
 * The answer to Dart waits in [pending] until the picker returns.
 */
class BackupFiles(private val activity: Activity) {
    private companion object {
        const val REQ_SAVE = 7301
        const val REQ_PICK = 7302
    }

    private var pending: MethodChannel.Result? = null
    private var pendingJson: String? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", "A file picker is already open", null)
            return
        }
        when (call.method) {
            "backupSave" -> {
                pendingJson = call.argument<String>("json") ?: ""
                pending = result
                val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("application/json")
                    .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "one-tracker-backup.json")
                launch(intent, REQ_SAVE)
            }
            "backupPick" -> {
                pending = result
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT)
                    .addCategory(Intent.CATEGORY_OPENABLE)
                    .setType("*/*")
                    .putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                launch(intent, REQ_PICK)
            }
        }
    }

    private fun launch(intent: Intent, code: Int) {
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, code)
        } catch (e: Exception) {
            finish { it.error("no_picker", e.message, null) }
        }
    }

    /** True if the result was ours. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQ_SAVE && requestCode != REQ_PICK) return false
        val uri = data?.data
        if (pending == null) return true
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finish { it.success(if (requestCode == REQ_SAVE) false else null) }
            return true
        }
        val json = pendingJson
        // Off the UI thread: the file can be a few MB.
        Thread {
            try {
                if (requestCode == REQ_SAVE) {
                    activity.contentResolver.openOutputStream(uri, "wt")!!.use { it.write((json ?: "").toByteArray()) }
                    activity.runOnUiThread { finish { it.success(true) } }
                } else {
                    val text = activity.contentResolver.openInputStream(uri)!!.use { String(it.readBytes()) }
                    activity.runOnUiThread { finish { it.success(text) } }
                }
            } catch (e: Exception) {
                activity.runOnUiThread { finish { it.error("file_failed", e.message, null) } }
            }
        }.start()
        return true
    }

    private fun finish(reply: (MethodChannel.Result) -> Unit) {
        val r = pending ?: return
        pending = null
        pendingJson = null
        reply(r)
    }
}
