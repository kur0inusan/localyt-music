package com.example.localyt_music
import android.content.ContentValues.TAG
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import com.arthenica.ffmpegkit.FFmpegKit
import com.arthenica.ffmpegkit.ReturnCode
import io.flutter.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.kuroinusan.localyt_music/youtubedl"
    private val EVENT_CHANNEL = "com.kuroinusan.localyt_music/youtubedl_event"
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
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
                        downloadYT(url, path, result)
                    } else {
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

    private fun downloadYT(url: String, path: String, result: MethodChannel.Result) {
        Thread {
            try{
                val dir = File(
                    android.os.Environment.getExternalStoragePublicDirectory(
                        android.os.Environment.DIRECTORY_DOWNLOADS
                    ).absolutePath + "/localyt_music/$path",
                    "youtubedl-android"
                )
                if (!dir.exists()) {
                    dir.mkdirs()
                }
                val request = YoutubeDLRequest(url);
                request.addOption("-o", "${dir.absolutePath}/%(title)s.%(ext)s")
                request.addOption("--yes-playlist")
                request.addOption("--extractor-args", "youtube:player_client=android")
                request.addOption("--user-agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                request.addOption("--download-archive", dir.absolutePath+"/downloaded.txt")
                request.addOption("--no-update")
                request.addOption("--no-warnings")
                request.addOption("--windows-filenames")

                YoutubeDL.getInstance().execute(request) { progress, etaInSeconds, line ->
                    Log.d(TAG, "progress: $progress, eta: $etaInSeconds")
                    Handler(Looper.getMainLooper()).post {
                        eventSink?.success(progress)
                    }
                }

                val downloadedFiles = dir.listFiles { file ->
                    file.extension != "txt" && file.extension != "mp3"
                }

                downloadedFiles?.forEach { originalFile ->
                    val mp3File = File(dir, "${originalFile.nameWithoutExtension}.mp3")

                    val cmd = "-i \"${originalFile.absolutePath}\" -vn -ab 320k -y \"${mp3File.absolutePath}\""

                    Log.d(TAG, "Starting 16KB-compliant FFmpeg-kit conversion: $cmd")

                    val session = FFmpegKit.execute(cmd)

                    if (ReturnCode.isSuccess(session.returnCode)) {
                        originalFile.delete()
                        Log.d(TAG, "Conversion successful, deleted original: ${originalFile.name}")
                    } else {
                        Log.e(TAG, "FFmpeg-kit conversion failed: ${session.returnCode}")
                    }
                }

                Handler(Looper.getMainLooper()).post {
                    result.success(0)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download failed", e)
                Handler(Looper.getMainLooper()).post {
                    result.error("DOWNLOAD_ERROR", e.message, null)
                }
            }
        }.start()
    }
}
