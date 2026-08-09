package com.kuroinusan.localyt_music

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaMetadataRetriever
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.yausername.youtubedl_android.YoutubeDL
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    companion object {
        private const val TAG = "LocalYTMusic"
        private const val CHANNEL = "com.kuroinusan.localyt_music/youtubedl"
        private const val EVENT_CHANNEL = "com.kuroinusan.localyt_music/youtubedl_event"
        private const val PERMISSION_REQUEST_CODE = 1001

        /// ダウンロード進捗を Flutter へ流すための EventChannel シンク。
        /// DownloadService(別プロセス相当のバックグラウンド)からも参照するため
        /// companion に置く。アプリがバックグラウンドで Flutter エンジンが
        /// 破棄されている間は null になり、その場合は通知のみで進捗を伝える。
        @Volatile
        private var progressSink: EventChannel.EventSink? = null

        private val mainHandler = Handler(Looper.getMainLooper())

        /// ダウンロードイベントを UI スレッド経由で Flutter へ送る。
        /// jobId を含めることで、別の画面や古いジョブのイベントを取り違えない。
        private fun emitDownloadEvent(
            type: String,
            jobId: String,
            path: String,
            progress: Double? = null,
            message: String? = null
        ) {
            val event = mutableMapOf<String, Any>(
                "type" to type,
                "jobId" to jobId,
                "path" to path
            )
            progress?.let { event["progress"] = it }
            message?.let { event["message"] = it }
            mainHandler.post {
                progressSink?.success(event)
            }
        }

        fun emitProgress(jobId: String, path: String, value: Double) {
            emitDownloadEvent("progress", jobId, path, progress = value)
        }

        fun emitCompleted(jobId: String, path: String) {
            emitDownloadEvent("completed", jobId, path, progress = 100.0)
        }

        fun emitError(jobId: String, path: String, message: String) {
            emitDownloadEvent("error", jobId, path, message = message)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestRuntimePermissions()
    }

    /// 通知(Android 13+)とストレージ(Android 9以下)の実行時権限をまとめて要求する
    private fun requestRuntimePermissions() {
        val permissions = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            permissions.add(Manifest.permission.READ_MEDIA_AUDIO)
        } else {
            permissions.add(Manifest.permission.READ_EXTERNAL_STORAGE)
            if (Build.VERSION.SDK_INT <= Build.VERSION_CODES.P) {
                permissions.add(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            }
        }
        val missing = permissions.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), PERMISSION_REQUEST_CODE)
        }
    }

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
                    val jobId = call.argument<String>("jobId")
                    val isUpdate = call.argument<Boolean>("isUpdate") ?: false
                    when {
                        url == null || path == null || jobId == null ->
                            result.error("INVALID_ARGS", "url, path and jobId are required", null)
                        DownloadService.isRunning ->
                            result.error("DOWNLOAD_BUSY", "Another download is already running", null)
                        !isAllowedUrl(url) ->
                            result.error("INVALID_URL", "Only YouTube URLs are supported", null)
                        !isSafePlaylistName(path) ->
                            result.error("INVALID_NAME", "Invalid playlist name", null)
                        else -> {
                            // ダウンロードはフォアグラウンドサービスに委譲し、アプリを
                            // 閉じても継続できるようにする。呼び出しは即座に完了させ、
                            // 進捗は EventChannel(emitProgress) 経由で通知する。
                            val intent = Intent(this, DownloadService::class.java).apply {
                                putExtra(DownloadService.EXTRA_URL, url)
                                putExtra(DownloadService.EXTRA_PATH, path)
                                putExtra(DownloadService.EXTRA_JOB_ID, jobId)
                                putExtra(DownloadService.EXTRA_IS_UPDATE, isUpdate)
                            }
                            ContextCompat.startForegroundService(this, intent)
                            result.success(0)
                        }
                    }
                }
                "getNetworkType" -> {
                    result.success(getNetworkType())
                }
                "hasAllFilesAccess" -> {
                    result.success(hasAllFilesAccess())
                }
                "requestAllFilesAccess" -> {
                    requestAllFilesAccess()
                    result.success(null)
                }
                "getAudioMetadata" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        // MediaMetadataRetrieverのファイルI/Oはメインスレッドで行うと
                        // 曲数が多いときにUIをフリーズさせるため、別スレッドで実行する。
                        Thread {
                            val metadata = getAudioMetadata(filePath)
                            Handler(Looper.getMainLooper()).post {
                                result.success(metadata)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path is required", null)
                    }
                }
                "getAudioMetadataBatch" -> {
                    val paths = call.argument<List<String>>("paths")
                    if (paths != null) {
                        Thread {
                            val metadataList = getAudioMetadataBatch(paths)
                            Handler(Looper.getMainLooper()).post {
                                result.success(metadataList)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "paths is required", null)
                    }
                }
                "getAudioThumbnail" -> {
                    val filePath = call.argument<String>("path")
                    if (filePath != null) {
                        Thread {
                            val retriever = MediaMetadataRetriever()
                            val picture = try {
                                retriever.setDataSource(filePath)
                                retriever.embeddedPicture
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to read audio thumbnail", e)
                                null
                            } finally {
                                retriever.release()
                            }
                            Handler(Looper.getMainLooper()).post {
                                result.success(picture)
                            }
                        }.start()
                    } else {
                        result.error("INVALID_ARGS", "path is required", null)
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
                    progressSink = sink
                }
                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            })
    }

    /// 全ファイルアクセス(MANAGE_EXTERNAL_STORAGE)が付与されているか。
    /// Android 10 以下では従来のストレージ権限で書き込めるため true を返す。
    private fun hasAllFilesAccess(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            Environment.isExternalStorageManager()
        } else {
            true
        }
    }

    /// 全ファイルアクセスの許可画面を開く。Android 11+ でのみ意味を持つ。
    private fun requestAllFilesAccess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return
        if (Environment.isExternalStorageManager()) return
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        } catch (e: Exception) {
            // 一部端末ではアプリ指定のintentが解決できないため、一覧画面を開く
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION))
            } catch (e2: Exception) {
                Log.e(TAG, "Failed to open all-files-access settings", e2)
            }
        }
    }

    /// 現在のネットワーク種別を返す。Wi-Fi/イーサネットは "wifi"、
    /// モバイル回線は "mobile"、未接続は "none"、その他は "other"。
    private fun getNetworkType(): String {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return "other"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val network = cm.activeNetwork ?: return "none"
            val caps = cm.getNetworkCapabilities(network) ?: return "none"
            return when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "mobile"
                else -> "other"
            }
        } else {
            @Suppress("DEPRECATION")
            val info = cm.activeNetworkInfo ?: return "none"
            @Suppress("DEPRECATION")
            return when (info.type) {
                ConnectivityManager.TYPE_WIFI, ConnectivityManager.TYPE_ETHERNET -> "wifi"
                ConnectivityManager.TYPE_MOBILE -> "mobile"
                else -> "other"
            }
        }
    }

    /// yt-dlpに渡すURLをYouTubeのhttps URLに限定する(Dart側の検証をすり抜けた場合の防波堤)
    private fun isAllowedUrl(url: String): Boolean {
        return try {
            val uri = android.net.Uri.parse(url)
            val host = uri.host?.lowercase() ?: return false
            uri.scheme == "https" &&
                (host == "www.youtube.com" || host == "youtube.com" ||
                    host == "m.youtube.com" || host == "music.youtube.com" ||
                    host == "youtu.be")
        } catch (e: Exception) {
            false
        }
    }

    /// プレイリスト名がベースディレクトリ外を指せないことを保証する
    private fun isSafePlaylistName(name: String): Boolean {
        if (name.isBlank() || name.length > 100) return false
        if (name.contains("/") || name.contains("\\") || name.contains("..")) return false
        if (name.startsWith(".")) return false
        val baseDir = playlistBaseDir()
        val target = File(baseDir, name)
        return target.canonicalPath.startsWith(baseDir.canonicalPath + File.separator)
    }

    private fun playlistBaseDir(): File {
        return File(
            android.os.Environment.getExternalStoragePublicDirectory(
                android.os.Environment.DIRECTORY_DOWNLOADS
            ),
            "localyt_music"
        )
    }

    /// 複数ファイルのメタデータを固定数のスレッドプールで並列抽出する。
    /// 1曲ずつMethodChannelを呼ぶと曲数分のIPCラウンドトリップが直列に
    /// 積み重なるため、まとめて1回の呼び出しで返す。
    private fun getAudioMetadataBatch(paths: List<String>): List<Map<String, String>> {
        if (paths.isEmpty()) return emptyList()
        val executor = Executors.newFixedThreadPool(minOf(4, paths.size))
        return try {
            val futures = paths.map { path -> executor.submit<Map<String, String>> { getAudioMetadata(path) } }
            futures.map { it.get() }
        } finally {
            executor.shutdown()
        }
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
}
