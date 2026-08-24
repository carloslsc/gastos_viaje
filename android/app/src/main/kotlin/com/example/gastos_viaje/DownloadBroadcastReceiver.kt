package com.example.gastos_viaje

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.widget.Toast
import java.io.File

/**
 * Handles the "Guardar en Descargas" custom action from the share chooser sheet.
 * Receives the temp-file path via extras and copies it to MediaStore.Downloads
 * (Android 10+) or the public Downloads directory (Android 9 and below).
 * No bytes are transferred through Binder — only a file-path string is used.
 */
class DownloadBroadcastReceiver : BroadcastReceiver() {

    companion object {
        const val EXTRA_FILE_PATH  = "filePath"
        const val EXTRA_FILE_NAME  = "fileName"
        const val EXTRA_MIME_TYPE  = "mimeType"
        const val EXTRA_SAVE_LABEL = "saveLabel"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val filePath  = intent.getStringExtra(EXTRA_FILE_PATH)  ?: return
        val fileName  = intent.getStringExtra(EXTRA_FILE_NAME)  ?: return
        val mimeType  = intent.getStringExtra(EXTRA_MIME_TYPE)  ?: return
        val saveLabel = intent.getStringExtra(EXTRA_SAVE_LABEL) ?: "Archivo guardado en Descargas"

        val src = File(filePath)
        if (!src.exists()) {
            Toast.makeText(context, "Error: archivo temporal no encontrado", Toast.LENGTH_SHORT).show()
            return
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(MediaStore.Downloads.MIME_TYPE,    mimeType)
                    put(MediaStore.Downloads.IS_PENDING,   1)
                }
                val resolver = context.contentResolver
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                ) ?: throw Exception("MediaStore insert devolvió null")

                resolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                }
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } else {
                @Suppress("DEPRECATION")
                val dir = Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_DOWNLOADS
                )
                if (!dir.exists()) dir.mkdirs()
                src.copyTo(File(dir, fileName), overwrite = true)
            }

            Toast.makeText(context, saveLabel, Toast.LENGTH_SHORT).show()
        } catch (e: Exception) {
            Toast.makeText(context, "Error al guardar: ${e.message}", Toast.LENGTH_SHORT).show()
        }
    }
}
