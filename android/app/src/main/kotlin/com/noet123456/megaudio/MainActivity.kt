package com.noet123456.megaudio

import android.content.Context
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Bridge used by lib/services/widget_service.dart to feed the
        // home-screen widget with the current track and playback state.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "megaudio/widget")
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences(
                    MegaudioWidgetProvider.PREFS,
                    Context.MODE_PRIVATE
                )
                when (call.method) {
                    "update" -> {
                        prefs.edit()
                            .putString("title", call.argument<String>("title") ?: "")
                            .putString("artist", call.argument<String>("artist") ?: "")
                            .putString("cover", call.argument<String>("coverPath") ?: "")
                            .putBoolean("playing", call.argument<Boolean>("playing") ?: false)
                            .putLong("pos", (call.argument<Number>("positionMs") ?: 0).toLong())
                            .putLong("dur", (call.argument<Number>("durationMs") ?: 0).toLong())
                            .putBoolean("light", call.argument<Boolean>("isLight") ?: false)
                            .apply()
                        MegaudioWidgetProvider.updateAll(this)
                        result.success(true)
                    }
                    "clear" -> {
                        prefs.edit().clear().apply()
                        MegaudioWidgetProvider.updateAll(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
