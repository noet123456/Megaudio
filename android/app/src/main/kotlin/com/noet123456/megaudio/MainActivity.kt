package com.noet123456.megaudio

import android.content.Context
import android.media.AudioDeviceInfo
import android.media.AudioManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- Home-screen widget bridge (lib/services/widget_service.dart) ---
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

        // --- Audio output devices (DAC detection) ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "megaudio/audio")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "outputs" -> result.success(audioOutputs())
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Connected output devices as reported by the platform. Android routes
     * playback to a USB-C DAC / 3.5mm adapter automatically; this only makes
     * the route visible inside the app.
     */
    private fun audioOutputs(): List<Map<String, Any?>> {
        val devices = ArrayList<Map<String, Any?>>()
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            for (d in am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)) {
                if (!d.isSink) continue
                val typeName = when (d.type) {
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB DAC"
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET -> "3.5mm"
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "Bluetooth"
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "Loa trong"
                    AudioDeviceInfo.TYPE_BUILTIN_EARPIECE -> "Loa thoại"
                    AudioDeviceInfo.TYPE_HDMI,
                    AudioDeviceInfo.TYPE_HDMI_ARC,
                    AudioDeviceInfo.TYPE_HDMI_EARC -> "HDMI"
                    else -> "Khác"
                }
                val isDac = d.type == AudioDeviceInfo.TYPE_USB_HEADSET ||
                    d.type == AudioDeviceInfo.TYPE_USB_DEVICE ||
                    d.type == AudioDeviceInfo.TYPE_USB_ACCESSORY
                devices.add(
                    mapOf(
                        "name" to (d.productName?.toString() ?: "Thiết bị"),
                        "type" to typeName,
                        "isDac" to isDac,
                        "maxSampleRate" to (d.sampleRates.maxOrNull() ?: 0)
                    )
                )
            }
        } catch (_: Throwable) {
        }
        return devices
    }
}
