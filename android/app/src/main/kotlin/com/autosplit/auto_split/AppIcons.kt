package com.autosplit.auto_split

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.AdaptiveIconDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Launcher icons of installed apps, as PNGs, for payee logos. Offline: only
 * packages the phone already has (and that AndroidManifest `<queries>` lists)
 * are visible. Rendered PNGs are kept in filesDir/icons, named by package, size
 * and the app's last update time, so an updated app gets a fresh icon.
 */
object AppIcons {
    private val main = Handler(Looper.getMainLooper())
    private val safeName = Regex("^[A-Za-z0-9._]+$")

    /** `appIcons({packages, size})` -> {package: png bytes}, installed ones only. */
    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        val packages = call.argument<List<String>>("packages") ?: emptyList()
        val size = (call.argument<Number>("size") ?: 160).toInt().coerceIn(32, 512)
        val app = context.applicationContext
        Thread {
            val out = HashMap<String, ByteArray>()
            for (p in packages.distinct().take(200)) {
                if (!safeName.matches(p)) continue
                try {
                    icon(app, p, size)?.let { out[p] = it }
                } catch (e: Exception) {
                    // One bad icon must not lose the rest.
                }
            }
            main.post { result.success(out) }
        }.start()
    }

    private fun icon(context: Context, pkg: String, size: Int): ByteArray? {
        val pm = context.packageManager
        val stamp = try {
            pm.getPackageInfo(pkg, 0).lastUpdateTime
        } catch (e: PackageManager.NameNotFoundException) {
            return null
        }
        val dir = File(context.filesDir, "icons").also { it.mkdirs() }
        val file = File(dir, "${pkg}_${size}_$stamp.png")
        if (file.exists()) return file.readBytes()

        val drawable = pm.getApplicationIcon(pkg)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && drawable is AdaptiveIconDrawable) {
            // Background + foreground layers, masked to the system shape, full colour.
            drawable.setBounds(0, 0, size, size)
        } else {
            // Legacy icons are full-bleed squares; inset so a circle crop keeps the art.
            val pad = (size * 0.12f).toInt()
            drawable.setBounds(pad, pad, size - pad, size - pad)
        }
        drawable.draw(canvas)
        val png = ByteArrayOutputStream().also { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
        bitmap.recycle()

        file.writeBytes(png)
        // Drop renders of older versions of this app's icon.
        val stale = Regex("^${Regex.escape(pkg)}_\\d+_\\d+\\.png$")
        dir.listFiles()?.filter { it != file && stale.matches(it.name) }?.forEach { it.delete() }
        return png
    }
}
