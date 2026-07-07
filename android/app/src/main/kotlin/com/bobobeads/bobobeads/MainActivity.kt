package com.bobobeads.bobobeads

import android.content.ContentValues
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bobobeads/photo_library",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "savePng" -> {
                    val bytes = call.arguments as? ByteArray
                    if (bytes == null) {
                        result.error("invalid_args", "PNG bytes are required.", null)
                    } else {
                        savePngToGallery(bytes, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun savePngToGallery(bytes: ByteArray, result: MethodChannel.Result) {
        val fileName = "bobobeads_pattern_${System.currentTimeMillis()}.png"
        val resolver = applicationContext.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(
                    MediaStore.Images.Media.RELATIVE_PATH,
                    "${Environment.DIRECTORY_PICTURES}/Bobobeads",
                )
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) {
            result.error("save_failed", "Unable to create gallery item.", null)
            return
        }

        try {
            resolver.openOutputStream(uri)?.use { output ->
                output.write(bytes)
            } ?: throw IllegalStateException("Unable to open gallery output stream.")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                values.clear()
                values.put(MediaStore.Images.Media.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            }

            result.success(null)
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            result.error("save_failed", error.localizedMessage, null)
        }
    }
}
