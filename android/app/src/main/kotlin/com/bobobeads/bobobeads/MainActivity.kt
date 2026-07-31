package com.bobobeads.bobobeads

import android.content.ContentValues
import android.content.res.Configuration
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Locale
import java.util.TimeZone

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bobobeads/device_identifiers",
        ).setMethodCallHandler { call, result ->
            if (call.method != "getDeviceInfo") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val metrics = resources.displayMetrics
            val isTablet = resources.configuration.screenLayout and
                Configuration.SCREENLAYOUT_SIZE_MASK >= Configuration.SCREENLAYOUT_SIZE_LARGE
            val orientation = when (resources.configuration.orientation) {
                Configuration.ORIENTATION_PORTRAIT -> 1
                Configuration.ORIENTATION_LANDSCAPE -> 2
                else -> 0
            }
            val androidId = Settings.Secure.getString(
                contentResolver,
                Settings.Secure.ANDROID_ID,
            )
            result.success(
                buildMap<String, Any> {
                    if (!androidId.isNullOrBlank()) put("androidId", androidId)
                    put("deviceType", if (isTablet) 1 else 0)
                    put("brand", Build.BRAND)
                    put("model", Build.MODEL)
                    put("os", 1)
                    put("osv", Build.VERSION.RELEASE)
                    put("width", metrics.widthPixels)
                    put("height", metrics.heightPixels)
                    put("orientation", orientation)
                    put("language", protoLanguage(Locale.getDefault().language))
                    put("timezone", TimeZone.getDefault().id)
                },
            )
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

    private fun protoLanguage(languageCode: String): String = when (languageCode.lowercase()) {
        "zh" -> "CHINESE"
        "en" -> "ENGLISH"
        "ru" -> "RUSSIAN"
        "vi" -> "VIETNAMESE"
        "pt" -> "PORTUGUESE"
        "id" -> "INDONESIAN"
        "ms" -> "MALAY"
        "th" -> "THAI"
        "fil", "tl" -> "FILIPINO"
        else -> "ENGLISH"
    }
}
