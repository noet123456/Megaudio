package com.noet123456.megaudio

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.SystemClock
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import java.io.File

/**
 * Square home-screen widget: album cover as background, gradient overlay
 * (white for bright covers, black for dark ones), title, artist, progress
 * bar and play/pause + prev/next buttons.
 *
 * Transport buttons are forwarded as media-button key events to the
 * audio_service MediaButtonReceiver, so they control the same media session
 * the notification and headset buttons use (no UI needed).
 */
class MegaudioWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_WIDGET = "com.noet123456.megaudio.ACTION_WIDGET"
        const val EXTRA_ACTION = "widget_action"
        const val PREFS = "megaudio_widget"

        private const val AUDIO_SERVICE_PKG = "com.ryanheise.audioservice"
        private const val AUDIO_SERVICE_RECEIVER = "com.ryanheise.audioservice.MediaButtonReceiver"

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, MegaudioWidgetProvider::class.java))
            for (id in ids) render(context, mgr, id)
        }

        private fun render(context: Context, mgr: AppWidgetManager, id: Int) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val title = prefs.getString("title", "") ?: ""
            val artist = prefs.getString("artist", "") ?: ""
            val cover = prefs.getString("cover", "") ?: ""
            val playing = prefs.getBoolean("playing", false)
            val pos = prefs.getLong("pos", 0L)
            val dur = prefs.getLong("dur", 0L)
            val light = prefs.getBoolean("light", false)
            val hasSong = title.isNotEmpty()

            val layout = if (hasSong && light) {
                R.layout.megaudio_widget_light
            } else {
                R.layout.megaudio_widget_dark
            }
            val views = RemoteViews(context.packageName, layout)

            views.setTextViewText(R.id.widget_title, if (hasSong) title else "Megaudio")
            views.setTextViewText(
                R.id.widget_artist,
                when {
                    !hasSong -> "Chạm để mở thư viện"
                    artist.isNotEmpty() -> artist
                    else -> ""
                }
            )

            val bitmap = decodeCover(cover)
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_cover, bitmap)
                views.setViewVisibility(R.id.widget_cover, View.VISIBLE)
                views.setViewVisibility(R.id.widget_gradient, View.VISIBLE)
                views.setViewVisibility(R.id.widget_logo, View.GONE)
            } else {
                // No artwork: show the app logo on a clean background.
                views.setViewVisibility(R.id.widget_cover, View.GONE)
                views.setViewVisibility(R.id.widget_gradient, View.GONE)
                views.setViewVisibility(R.id.widget_logo, View.VISIBLE)
            }

            views.setImageViewResource(
                R.id.widget_play,
                if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play
            )

            if (dur > 0L) {
                views.setProgressBar(
                    R.id.widget_progress,
                    dur.toInt(),
                    pos.coerceIn(0L, dur).toInt(),
                    false
                )
            } else {
                views.setProgressBar(R.id.widget_progress, 100, 0, false)
            }

            views.setOnClickPendingIntent(R.id.widget_play, actionIntent(context, "toggle", 1))
            views.setOnClickPendingIntent(R.id.widget_prev, actionIntent(context, "prev", 2))
            views.setOnClickPendingIntent(R.id.widget_next, actionIntent(context, "next", 3))
            views.setOnClickPendingIntent(R.id.widget_root, actionIntent(context, "open", 4))

            mgr.updateAppWidget(id, views)
        }

        private fun actionIntent(context: Context, action: String, requestCode: Int): PendingIntent {
            val intent = Intent(context, MegaudioWidgetProvider::class.java).apply {
                this.action = ACTION_WIDGET
                putExtra(EXTRA_ACTION, action)
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        private fun decodeCover(path: String): Bitmap? {
            if (path.isEmpty()) return null
            return try {
                if (!File(path).exists()) return null
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, bounds)
                var sample = 1
                val target = 512
                while (bounds.outWidth / (sample * 2) >= target &&
                    bounds.outHeight / (sample * 2) >= target
                ) {
                    sample *= 2
                }
                BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            } catch (_: Throwable) {
                null
            }
        }

        /** Sends a media-button key event to the audio_service receiver. */
        private fun sendMediaKey(context: Context, keyCode: Int) {
            val now = SystemClock.uptimeMillis()
            val down = KeyEvent(now, now, KeyEvent.ACTION_DOWN, keyCode, 0)
            val up = KeyEvent(now, now, KeyEvent.ACTION_UP, keyCode, 0)
            val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
                setComponent(ComponentName(AUDIO_SERVICE_PKG, AUDIO_SERVICE_RECEIVER))
                putExtra(Intent.EXTRA_KEY_EVENT, down)
            }
            context.sendBroadcast(intent)
            intent.putExtra(Intent.EXTRA_KEY_EVENT, up)
            context.sendBroadcast(intent)
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            render(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action != ACTION_WIDGET) return
        when (intent.getStringExtra(EXTRA_ACTION)) {
            "toggle" -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            "next" -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            "prev" -> sendMediaKey(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            "open" -> {
                val launch = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                }
                context.startActivity(launch)
            }
        }
    }
}
