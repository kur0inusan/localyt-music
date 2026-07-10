package com.kuroinusan.localyt_music

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.Log
import java.io.File

/// プレイリストのダウンロードをアプリのバックグラウンドでも継続させるための
/// フォアグラウンドサービス。以前は MainActivity 内の素の Thread で実行して
/// いたため、アプリを閉じるとプロセスごと OS に kill されてダウンロードが
/// 中断していた（特に曲数の多いプレイリストで顕著）。フォアグラウンド通知を
/// 出すことで OS にプロセスを維持させ、長時間のダウンロードを完走させる。
class DownloadService : Service() {

    companion object {
        private const val TAG = "LocalYTMusic"
        private const val CHANNEL_ID = "localyt_download"
        private const val PROGRESS_NOTIFICATION_ID = 2001
        private const val COMPLETE_NOTIFICATION_ID = 2002

        const val EXTRA_URL = "url"
        const val EXTRA_PATH = "path"

        /// ダウンロードが実行中かどうか。多重起動を避けるために参照する。
        @Volatile
        var isRunning: Boolean = false
            private set
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val url = intent?.getStringExtra(EXTRA_URL)
        val path = intent?.getStringExtra(EXTRA_PATH)

        if (url == null || path == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        // 既に別のダウンロードが進行中の場合は、新しい要求を無視する
        // (フォアグラウンド通知やスレッドの二重管理を避けるため)。
        if (isRunning) {
            Log.w(TAG, "Download already running; ignoring new request for $path")
            return START_NOT_STICKY
        }

        isRunning = true
        startForegroundWithNotification(path)

        Thread {
            try {
                runDownload(url, path)
            } catch (e: Exception) {
                Log.e(TAG, "Playlist download failed", e)
                MainActivity.emitProgress(-1.0)
                showCompletionNotification(path, success = false)
            } finally {
                isRunning = false
                stopForegroundCompat()
                stopSelf()
            }
        }.start()

        return START_NOT_STICKY
    }

    private fun runDownload(url: String, path: String) {
        val playlistURLs = getPlaylistURLs(url)
        MainActivity.emitProgress(0.0)
        updateProgressNotification(path, 0, playlistURLs.size)

        playlistURLs.forEachIndexed { index, playlistURL ->
            try {
                downloadSingleYT(playlistURL, path)
            } catch (e: Exception) {
                Log.e(TAG, "Skipping video that failed to download: $playlistURL", e)
            }
            val completed = index + 1
            val progress = (completed.toDouble() / playlistURLs.size) * 100
            MainActivity.emitProgress(progress)
            updateProgressNotification(path, completed, playlistURLs.size)
        }

        MainActivity.emitProgress(100.0)
        showCompletionNotification(path, success = true)
    }

    // ---- 通知まわり ------------------------------------------------------

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "ダウンロード",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "プレイリストのダウンロード進捗"
                    setShowBadge(false)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    private fun contentIntent(): PendingIntent? {
        val launch = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }
        return PendingIntent.getActivity(this, 0, launch, flags)
    }

    private fun buildProgressNotification(
        path: String,
        completed: Int,
        total: Int
    ): Notification {
        val indeterminate = total <= 0
        val text = if (indeterminate) {
            "ダウンロードを準備中..."
        } else {
            "$completed / $total 曲"
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(path)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(if (indeterminate) 0 else total, completed, indeterminate)
            .setContentIntent(contentIntent())
            .build()
    }

    private fun startForegroundWithNotification(path: String) {
        ensureChannel()
        val notification = buildProgressNotification(path, 0, 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                PROGRESS_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(PROGRESS_NOTIFICATION_ID, notification)
        }
    }

    private fun updateProgressNotification(path: String, completed: Int, total: Int) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(PROGRESS_NOTIFICATION_ID, buildProgressNotification(path, completed, total))
    }

    private fun showCompletionNotification(path: String, success: Boolean) {
        ensureChannel()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(path)
            .setContentText(if (success) "ダウンロードが完了しました" else "ダウンロードに失敗しました")
            .setSmallIcon(
                if (success) android.R.drawable.stat_sys_download_done
                else android.R.drawable.stat_notify_error
            )
            .setOngoing(false)
            .setAutoCancel(true)
            .setContentIntent(contentIntent())
            .build()
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(COMPLETE_NOTIFICATION_ID, notification)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    // ---- ダウンロード処理 (旧 MainActivity から移設) --------------------

    private fun playlistBaseDir(): File {
        return File(
            android.os.Environment.getExternalStoragePublicDirectory(
                android.os.Environment.DIRECTORY_DOWNLOADS
            ),
            "localyt_music"
        )
    }

    private fun getPlaylistURLs(url: String): Array<String> {
        val request = YoutubeDLRequest(url)
        request.addOption("--dump-json")
        request.addOption("--flat-playlist")
        request.addOption("--yes-playlist")
        request.addOption("--extractor-args", "youtube:player_client=android")
        request.addOption("--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        request.addOption("--no-update")
        request.addOption("--no-warnings")

        val response = YoutubeDL.getInstance().execute(request)
        val playlistURLs = mutableListOf<String>()

        fun addEntryURL(entry: org.json.JSONObject) {
            val webpageURL = entry.optString("webpage_url")
            val entryURL = entry.optString("url")
            val videoID = entry.optString("id")

            val resolvedURL = when {
                webpageURL.startsWith("http") -> webpageURL
                entryURL.startsWith("http") -> entryURL
                entryURL.isNotBlank() -> "https://www.youtube.com/watch?v=$entryURL"
                videoID.isNotBlank() -> "https://www.youtube.com/watch?v=$videoID"
                else -> ""
            }

            if (resolvedURL.isNotBlank()) {
                playlistURLs.add(resolvedURL)
            }
        }

        response.out
            .lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .forEach { line ->
                val json = org.json.JSONObject(line)
                val entries = json.optJSONArray("entries")

                if (entries != null) {
                    for (i in 0 until entries.length()) {
                        val entry = entries.optJSONObject(i) ?: continue
                        addEntryURL(entry)
                    }
                } else {
                    addEntryURL(json)
                }
            }

        return playlistURLs.toTypedArray()
    }

    private fun downloadSingleYT(url: String, path: String) {
        val playlistDir = File(playlistBaseDir(), path)
        if (!playlistDir.exists()) {
            playlistDir.mkdirs()
        }
        val request = YoutubeDLRequest(url)
        request.addOption("-o", "${playlistDir.absolutePath}/%(title)s.%(ext)s")
        request.addOption("--no-playlist")
        request.addOption("--extractor-args", "youtube:player_client=android")
        request.addOption("--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        request.addOption("--download-archive", playlistDir.absolutePath + "/downloaded.txt")
        request.addOption("--no-update")
        request.addOption("--no-warnings")
        request.addOption("--windows-filenames")
        request.addOption("--write-thumbnail")
        request.addOption("--write-info-json")

        YoutubeDL.getInstance().execute(request) { progress, etaInSeconds, _ ->
            Log.d(TAG, "progress: $progress, eta: $etaInSeconds")
        }

        val downloadedFiles = playlistDir.listFiles { file ->
            val ext = file.extension.lowercase()
            ext != "txt" && ext != "mp3" && ext != "jpg" && ext != "png" && ext != "webp" && ext != "json"
        }

        downloadedFiles?.forEach { originalFile ->
            val thumbnailFile = findThumbnailFile(playlistDir, originalFile.nameWithoutExtension)

            val mp3File = File(playlistDir, "${originalFile.nameWithoutExtension}.mp3")
            val infoFile = File(playlistDir, "${originalFile.nameWithoutExtension}.info.json")
            val infoJson = if (infoFile.exists()) {
                org.json.JSONObject(infoFile.readText())
            } else {
                null
            }
            val title = infoJson?.optString("title").orEmpty()
            val artist = infoJson?.optString("artist").orEmpty()
                .ifBlank { infoJson?.optString("uploader").orEmpty() }
                .ifBlank { infoJson?.optString("channel").orEmpty() }

            // 文字列連結ではなく引数配列で渡すことで、曲タイトル等に含まれる
            // 引用符・空白による引数インジェクションを構造的に防ぐ
            val args = mutableListOf("-i", originalFile.absolutePath)
            if (thumbnailFile != null) {
                args.addAll(listOf("-i", thumbnailFile.absolutePath))
            }
            args.add("-y")
            args.addAll(listOf("-map", "0:a:0"))
            if (thumbnailFile != null) {
                args.addAll(listOf("-map", "1:v:0"))
            } else {
                args.add("-vn")
            }
            args.addAll(listOf("-c:a", "libmp3lame", "-b:a", "320k"))
            if (thumbnailFile != null) {
                args.addAll(listOf("-c:v", "mjpeg"))
                args.addAll(listOf("-disposition:v", "attached_pic"))
                args.addAll(listOf("-metadata:s:v", "title=Album cover"))
                args.addAll(listOf("-metadata:s:v", "comment=Cover (front)"))
            }
            args.addAll(listOf("-id3v2_version", "3", "-write_id3v1", "1"))
            if (title.isNotBlank()) {
                args.addAll(listOf("-metadata", "title=$title"))
            }
            if (artist.isNotBlank()) {
                args.addAll(listOf("-metadata", "artist=$artist"))
            }
            args.addAll(listOf("-metadata", "album=$path"))
            args.add(mp3File.absolutePath)

            Log.d(TAG, "Starting FFmpeg-kit conversion: ${originalFile.name}")

            val session = FFmpegKit.executeWithArguments(args.toTypedArray())

            if (ReturnCode.isSuccess(session.returnCode)) {
                originalFile.delete()
                if (thumbnailFile != null && hasEmbeddedPicture(mp3File)) {
                    thumbnailFile.delete()
                } else if (thumbnailFile != null) {
                    Log.e(TAG, "Thumbnail was not embedded; keeping sidecar file: ${thumbnailFile.name}")
                }
                if (infoFile.exists()) {
                    infoFile.delete()
                }
                MediaScannerConnection.scanFile(
                    applicationContext,
                    arrayOf(mp3File.absolutePath),
                    arrayOf("audio/mpeg"),
                    null
                )
                Log.d(TAG, "Conversion successful, deleted original: ${originalFile.name}")
            } else {
                Log.e(TAG, "FFmpeg-kit conversion failed: ${session.returnCode}")
            }
        }
    }

    private fun findThumbnailFile(dir: File, baseName: String): File? {
        val extensions = arrayOf("jpg", "jpeg", "png", "webp")
        return extensions
            .map { extension -> File(dir, "$baseName.$extension") }
            .firstOrNull { file -> file.exists() }
    }

    private fun hasEmbeddedPicture(file: File): Boolean {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(file.absolutePath)
            retriever.embeddedPicture != null
        } catch (e: Exception) {
            Log.e(TAG, "Failed to verify embedded thumbnail", e)
            false
        } finally {
            retriever.release()
        }
    }
}
