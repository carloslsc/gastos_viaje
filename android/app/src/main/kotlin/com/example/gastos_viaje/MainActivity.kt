package com.example.gastos_viaje

import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.garrobo.nivela/downloads"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    val filePath  = call.argument<String>("filePath")  ?: return@setMethodCallHandler result.error("ARG", "filePath missing", null)
                    val fileName  = call.argument<String>("fileName")  ?: return@setMethodCallHandler result.error("ARG", "fileName missing", null)
                    val mimeType  = call.argument<String>("mimeType")  ?: return@setMethodCallHandler result.error("ARG", "mimeType missing", null)
                    saveToDownloads(filePath, fileName, mimeType, result)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(
        filePath: String,
        fileName: String,
        mimeType: String,
        result: MethodChannel.Result
    ) {
        try {
            val src = File(filePath)
            if (!src.exists()) {
                result.error("NOT_FOUND", "Temp file not found: $filePath", null)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // Android 10+ — MediaStore.Downloads (no WRITE permission needed)
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE,    mimeType)
                    put(MediaStore.Downloads.IS_PENDING,   1)
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                ) ?: run {
                    result.error("INSERT", "MediaStore insert failed", null)
                    return
                }
                contentResolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                contentResolver.update(uri, values, null, null)
                result.success(uri.toString())
            } else {
                // Android 9 and below — public Downloads directory
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                if (!dir.exists()) dir.mkdirs()
                val dest = File(dir, fileName)
                src.copyTo(dest, overwrite = true)
                @Suppress("DEPRECATION")
                sendBroadcast(
                    Intent(Intent.ACTION_MEDIA_SCANNER_SCAN_FILE, Uri.fromFile(dest))
                )
                result.success(dest.absolutePath)
            }
        } catch (e: Exception) {
            result.error("SAVE_FAILED", e.message, null)
        }
    }
}
