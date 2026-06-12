package com.example.localyt_music
import android.content.ContentValues.TAG
import android.media.MediaMetadataRetriever
import android.media.MediaScannerConnection
import android.os.Handler
import android.os.Looper
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    private val CHANNEL = "com.kuroinusan.localyt_music/youtubedl"
    private val EVENT_CHANNEL = "com.kuroinusan.localyt_music/youtubedl_event"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        Thread {
            try {
                YoutubeDL.getInstance().init(this)
                YoutubeDL.getInstance().updateYoutubeDL(this, YoutubeDL.UpdateChannel._STABLE)

                Log.d(TAG, "Initialization complete")
            } catch (e: Exception) {
                Log.e(TAG, "Initialization failed", e)
            }
        }.start()


        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "downloadYT" -> {
                    val url = call.argument<String>("url")
                    val path = call.argument<String>("path")
                    if (url != null && path != null) {
                        downloadPlaylist(url, path, result)
                    } else {
                        result.error("error", "error", null)
                    }
                }
                "getAudioMetadata" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        result.success(getAudioMetadata(filePath))
                    } else {
                        result.error("error", "error", null)
                    }
                }
                "getAudioThumbnail" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        val retriever = MediaMetadataRetriever()
                        try {
                            retriever.setDataSource(filePath)
                            result.success(retriever.embeddedPicture)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to read audio thumbnail", e)
                            result.success(null)
                        } finally {
                            retriever.release()
                        }
                    }else{
                        result.error("error", "error", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
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

    private fun getAudioMetadata(filePath: String): Map<String, String> {
        val retriever = MediaMetadataRetriever()
        return try {
            retriever.setDataSource(filePath)
            mapOf(
                "title" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE) ?: ""),
                "album" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM) ?: ""),
                "artist" to (retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST) ?: "")
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read audio metadata", e)
            emptyMap()
        } finally {
            retriever.release()
        }
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

    private fun downloadPlaylist(url: String, path: String, result: MethodChannel.Result) {
        Thread {
            try {
                val playlistURLs = getPlaylistURLs(url)
                Handler(Looper.getMainLooper()).post {
                    eventSink?.success(0.0)
                }
                playlistURLs.forEachIndexed { index, playlistURL ->
                    try {
                        downloadSingleYT(playlistURL, path)
                    } catch (e: Exception) {
                        Log.e(TAG, "Skipping video that failed to download: $playlistURL", e)
                    }
                    val progress = ((index + 1).toDouble() / playlistURLs.size) * 100
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(progress)
                    }
                }
                Handler(Looper.getMainLooper()).post {
                    result.success(0)
                    eventSink?.success(100.0)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Playlist download failed", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("DOWNLOAD_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun downloadSingleYT(url: String, path: String) {
        val playlistDir = File(
            android.os.Environment.getExternalStoragePublicDirectory(
                android.os.Environment.DIRECTORY_DOWNLOADS
            ).absolutePath + "/localyt_music/$path"
        )
        if (!playlistDir.exists()) {
            playlistDir.mkdirs()
        }
        val request = YoutubeDLRequest(url)
        request.addOption("-o", "${playlistDir.absolutePath}/%(title)s.%(ext)s")
        request.addOption("--no-playlist")
        request.addOption("--extractor-args", "youtube:player_client=android")
        request.addOption("--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
        request.addOption("--download-archive", playlistDir.absolutePath+"/downloaded.txt")
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
//                    print(originalFile.name)
//                    print(originalFile.nameWithoutExtension)

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

            fun escapeMetadata(value: String): String {
                return value.replace("\\", "\\\\").replace("\"", "\\\"")
            }

            var cmd = "-i \"${originalFile.absolutePath}\""
            if (thumbnailFile != null) {
                cmd += " -i \"${thumbnailFile.absolutePath}\""
            }
            cmd += " -y"
            cmd += " -map 0:a:0"
            if (thumbnailFile != null) {
                cmd += " -map 1:v:0"
            } else {
                cmd += " -vn"
            }
            cmd += " -c:a libmp3lame -b:a 320k"
            if (thumbnailFile != null) {
                cmd += " -c:v mjpeg"
                cmd += " -disposition:v attached_pic"
                cmd += " -metadata:s:v title=\"Album cover\""
                cmd += " -metadata:s:v comment=\"Cover (front)\""
            }
            cmd += " -id3v2_version 3 -write_id3v1 1"
            if (title.isNotBlank()) {
                cmd += " -metadata title=\"${escapeMetadata(title)}\""
            }
            if (artist.isNotBlank()) {
                cmd += " -metadata artist=\"${escapeMetadata(artist)}\""
            }
            cmd += " -metadata album=\"${escapeMetadata(path)}\""

            cmd += " \"${mp3File.absolutePath}\""
            Log.d(TAG, "Starting 16KB-compliant FFmpeg-kit conversion: $cmd")

            val session = FFmpegKit.execute(cmd)

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
}
