package com.noet123456.megaudio

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import com.ryanheise.audioservice.MediaButtonReceiver
import java.io.File

/**
 * Square home-screen widget: album cover as background, gradient overlay
 * (white for bright covers, black for dark ones), centred title, artist,
 * progress bar and play/pause + prev/next buttons.
 *
 * Transport buttons use the exact same media-button PendingIntents the
 * audio_service notification uses, so they control the active media session
 * (works while the app is in the background, no UI needed). Tapping the rest
 * of the widget opens the app.
 */
class MegaudioWidgetProvider : AppWidgetProvider() {

    companion object {
        const val PREFS = "megaudio_widget"

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

            views.setOnClickPendingIntent(
                R.id.widget_play,
                mediaPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE, 1)
            )
            views.setOnClickPendingIntent(
                R.id.widget_prev,
                mediaPendingIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 2)
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                mediaPendingIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT, 3)
            )
            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context))

            mgr.updateAppWidget(id, views)
        }

        /**
         * Mirrors audio_service's own notification action intents: a broadcast
         * to the app's MediaButtonReceiver carrying a KEYCODE_MEDIA_* event.
         * The ComponentName must resolve inside THIS app's package (the plugin
         * class is merged into the APK), not the plugin's own package.
         */
        private fun mediaPendingIntent(context: Context, keyCode: Int, requestCode: Int): PendingIntent {
            val intent = Intent(context, MediaButtonReceiver::class.java).apply {
                action = Intent.ACTION_MEDIA_BUTTON
                putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }

        /** Launcher-sent activity intents are allowed to start the app in the
         *  background (unlike a broadcast receiver calling startActivity). */
        private fun openAppIntent(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            return PendingIntent.getActivity(
                context,
                4,
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
}
