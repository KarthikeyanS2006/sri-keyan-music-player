package com.srikeyan.music

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.srikeyan.music/downloads"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "saveToDownloads") {
                val filePath = call.argument<String>("filePath")
                val fileName = call.argument<String>("fileName")
                if (filePath != null && fileName != null) {
                    try {
                        val savedPath = saveToDownloads(filePath, fileName)
                        if (savedPath != null) {
                            result.success(savedPath)
                        } else {
                            result.error("SAVE_FAILED", "Could not save file", null)
                        }
                    } catch (e: Exception) {
                        result.error("SAVE_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_ARGS", "filePath and fileName required", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(filePath: String, fileName: String): String? {
        val sourceFile = File(filePath)
        if (!sourceFile.exists()) return null

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Android 10+: Use MediaStore
            val contentValues = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                put(MediaStore.Downloads.MIME_TYPE, "audio/mpeg")
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Keyan Music")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }

            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, contentValues)
                ?: return null

            try {
                resolver.openOutputStream(uri)?.use { outputStream ->
                    FileInputStream(sourceFile).use { inputStream ->
                        inputStream.copyTo(outputStream)
                    }
                }

                contentValues.clear()
                contentValues.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, contentValues, null, null)

                sourceFile.delete()
                return uri.toString()
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                return null
            }
        } else {
            // Android 9 and below: Direct file copy
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val appDir = File(downloadsDir, "Keyan Music")
            if (!appDir.exists()) appDir.mkdirs()

            val destFile = File(appDir, fileName)
            sourceFile.copyTo(destFile, overwrite = true)
            sourceFile.delete()

            // Notify media scanner
            android.media.MediaScannerConnection.scanFile(this, arrayOf(destFile.absolutePath), arrayOf("audio/mpeg"), null)
            return destFile.absolutePath
        }
    }
}
