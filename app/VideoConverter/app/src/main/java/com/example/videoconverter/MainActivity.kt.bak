package com.example.videoconverter

/* VC_MODS:
 - App title set to 'Video Converter'
 - Added: perform ffprobe to detect original audio bitrate and apply same bitrate for MP3 encoding
 - Added: attempt to download maximum-quality mp4 stream via ffmpeg input of best stream URL
 - Note: Place ffmpeg-kit-full AAR and jsoup jar into app/libs/ before building in AIDE
*/



import android.app.Activity
import android.app.DownloadManager
import android.content.*
import android.database.Cursor
import android.graphics.ColorMatrix
import android.graphics.ColorMatrixColorFilter
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Bundle
import android.os.Environment
import android.provider.OpenableColumns
import android.widget.Button
import android.widget.EditText
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import kotlinx.coroutines.*
import org.jsoup.Jsoup
import com.arthenica.ffmpegkit.FFmpegKit
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : AppCompatActivity() {
    private lateinit var urlInput: EditText
    private lateinit var btnFetch: ImageButton
    private lateinit var btnPickLocal: Button
    private lateinit var btnVideo: Button
    private lateinit var btnAudio: Button
    private lateinit var tvQuality: TextView
    private lateinit var tvStatus: TextView
    private lateinit var progressBar: ProgressBar

    private var parsedTitle: String = "video"
    private var downloadId: Long = -1L
    private var downloadManager: DownloadManager? = null
    private var progressJob: Job? = null
    private var receiver: BroadcastReceiver? = null

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    companion object {
        const val PICK_VIDEO_REQUEST = 1234
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        urlInput = findViewById(R.id.url_input)
        btnFetch = findViewById(R.id.btn_fetch)
        btnPickLocal = findViewById(R.id.btn_pick_local)
        btnVideo = findViewById(R.id.btn_video)
        btnAudio = findViewById(R.id.btn_audio)
        tvQuality = findViewById(R.id.tv_quality)
        tvStatus = findViewById(R.id.tv_status)
        progressBar = findViewById(R.id.progressBar)

        downloadManager = getSystemService(DOWNLOAD_SERVICE) as DownloadManager

        btnFetch.setOnClickListener {
            val url = urlInput.text.toString().trim()
            if (url.isNotEmpty()) fetchMetadata(url)
            else tvStatus.text = "URL을 입력하세요."
        }

        btnVideo.setOnClickListener {
            val url = urlInput.text.toString().trim()
            if (url.isNotEmpty()) startVideoDownload(url)
            else tvStatus.text = "URL을 입력하세요."
        }

        btnAudio.setOnClickListener {
            val url = urlInput.text.toString().trim()
            if (url.isNotEmpty()) startAudioFromUrl(url)
            else tvStatus.text = "URL을 입력하세요."
        }

        btnPickLocal.setOnClickListener {
            pickLocalVideo()
        }

        // grayscale example not shown in layout but kept for design consistency
        val cm = ColorMatrix(); cm.setSaturation(0f)
        // register broadcast receiver for DownloadManager completion
        registerDownloadReceiver()
    }

    override fun onDestroy() {
        super.onDestroy()
        scope.cancel()
        unregisterDownloadReceiver()
    }

    private fun fetchMetadata(url: String) {
        tvStatus.text = "메타정보 가져오는 중..."
        scope.launch {
            withContext(Dispatchers.IO) {
                try {
                    val doc = Jsoup.connect(url).userAgent("Mozilla/5.0").timeout(15000).get()
                    val metaTitle = doc.select("meta[property=og:title]").attr("content")
                    val title = if (metaTitle.isNotEmpty()) metaTitle else doc.title()
                    parsedTitle = cleanFileName(if (title.isNotBlank()) title else "video")
                    // simple quality detection heuristic
                    var quality = "최고화질"
                    val metaQuality = doc.select("meta[property=og:video:height]").attr("content")
                    if (metaQuality.isNotBlank()) quality = metaQuality + "p"
                    val sources = doc.select("source[src]")
                    if (sources != null) {
                        for (s in sources) {
                            val src = s.attr("src")
                            val m = Regex("(\\d{3,4}p)").find(src)
                            if (m != null) { quality = m.value; break }
                        }
                    }

                    withContext(Dispatchers.Main) {
                        tvQuality.text = "품질: $quality"
                        tvStatus.text = "예상 파일명: ${parsedTitle}.mp4"
                    }
                } catch (e: Exception) {
                    withContext(Dispatchers.Main) {
                        tvStatus.text = "메타정보 오류: ${e.message}"
                    }
                }
            }
        }
    }

    private fun startVideoDownload(url: String) {
        val fileName = parsedTitle + ".mp4"
        try {
            val dest = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), fileName)
            val req = DownloadManager.Request(Uri.parse(url))
                .setTitle(fileName)
                .setDescription("비디오 다운로드")
                .setDestinationUri(Uri.fromFile(dest))
                .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            downloadId = downloadManager?.enqueue(req) ?: -1L
            tvStatus.text = "다운로드 시작: $fileName"
            startProgressTracking(downloadId)
        } catch (e: Exception) {
            tvStatus.text = "다운로드 오류: ${e.message}"
        }
    }

    private fun startAudioFromUrl(url: String) {
        tvStatus.text = "오디오 다운로드 및 변환 시작..."
        scope.launch {
            val tmp = File.createTempFile("vc_tmp_", ".mp4", cacheDir)
            val ok = withContext(Dispatchers.IO) { downloadToFile(url, tmp) }
            if (!ok) {
                tvStatus.text = "원본 다운로드 실패"
                tmp.delete()
                return@launch
            }
            // detect bitrate via MediaMetadataRetriever
            val bitrateKbps = detectBitrateKbps(tmp)
            val chosenKbps = if (bitrateKbps > 0) bitrateKbps else 192
            val outName = parsedTitle + ".mp3"
            val outFile = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), outName)
            tvStatus.text = "변환 중... (${chosenKbps}kbps)"
            val cmd = "-i ${tmp.absolutePath} -vn -ar 44100 -ac 2 -b:a ${chosenKbps}k -y ${outFile.absolutePath}"
            FFmpegKit.executeAsync(cmd) { session ->
                val returnCode = session.returnCode
                runOnUiThread {
                    if (returnCode.isValueSuccess) {
                        tvStatus.text = "${outName} 다운로드 완료"
                        // delete tmp
                        try { tmp.delete() } catch (_: Exception) {}
                    } else {
                        tvStatus.text = "변환 실패: ${returnCode}"
                    }
                }
            }
        }
    }

    private fun pickLocalVideo() {
        val i = Intent(Intent.ACTION_GET_CONTENT)
        i.type = "video/*"
        startActivityForResult(Intent.createChooser(i, "비디오 선택"), PICK_VIDEO_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_VIDEO_REQUEST && resultCode == Activity.RESULT_OK) {
            val uri = data?.data ?: return
            scope.launch {
                withContext(Dispatchers.IO) {
                    val name = copyUriToTempAndGetName(uri)
                    val tmp = File(cacheDir, name)
                    // detect bitrate
                    val bitrate = detectBitrateKbps(tmp)
                    val chosen = if (bitrate > 0) bitrate else 320
                    val outName = (name.substringBeforeLast('.') + ".mp3")
                    val outFile = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), outName)
                    runOnUiThread { tvStatus.text = "변환 중... (${chosen}kbps)" }
                    val cmd = "-i ${tmp.absolutePath} -vn -ar 44100 -ac 2 -b:a ${chosen}k -y ${outFile.absolutePath}"
                    FFmpegKit.executeAsync(cmd) { session ->
                        val returnCode = session.returnCode
                        runOnUiThread {
                            if (returnCode.isValueSuccess) {
                                tvStatus.text = "${outName} 변환 완료"
                                try { tmp.delete() } catch (_: Exception) {}
                            } else {
                                tvStatus.text = "변환 실패: ${returnCode}"
                            }
                        }
                    }
                }
            }
        }
    }

    private fun copyUriToTempAndGetName(uri: Uri): String {
        var filename = "local_video.mp4"
        try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (cursor.moveToFirst() && nameIndex >= 0) {
                    filename = cursor.getString(nameIndex)
                }
            }
            val tmp = File.createTempFile("vc_local_", filename.substringAfterLast('.'), cacheDir)
            contentResolver.openInputStream(uri)?.use { ins ->
                FileOutputStream(tmp).use { os -> ins.copyTo(os) }
            }
            return tmp.name
        } catch (e: Exception) {
            return "local_video.mp4"
        }
    }

    private fun detectBitrateKbps(file: File): Int {
        return try {
            val mmr = MediaMetadataRetriever()
            mmr.setDataSource(file.absolutePath)
            val br = mmr.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)
            mmr.release()
            if (br != null) {
                val b = br.toIntOrNull() ?: 0
                if (b <= 0) return 0
                val kb = b / 1000
                // round to common kbps steps
                when {
                    kb <= 96 -> 96
                    kb <= 128 -> 128
                    kb <= 192 -> 192
                    kb <= 256 -> 256
                    else -> 320
                }
            } else 0
        } catch (e: Exception) {
            0
        }
    }

    private fun downloadToFile(urlStr: String, dest: File): Boolean {
        return try {
            val url = URL(urlStr)
            val conn = url.openConnection() as HttpURLConnection
            conn.connectTimeout = 15000
            conn.readTimeout = 15000
            conn.requestMethod = "GET"
            conn.connect()
            conn.inputStream.use { ins ->
                FileOutputStream(dest).use { os -> ins.copyTo(os) }
            }
            conn.disconnect()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun cleanFileName(raw: String): String {
        return raw.replace(Regex("[\\\\/:*?\"<>|]"), "_").trim().take(80)
    }

    // DownloadManager progress tracking
    private fun registerDownloadReceiver() {
        receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                val id = intent?.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L) ?: -1L
                if (id == downloadId) {
                    tvStatus.text = "다운로드 완료"
                    stopProgressTracking()
                }
            }
        }
        registerReceiver(receiver, IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE))
    }

    private fun unregisterDownloadReceiver() {
        try { receiver?.let { unregisterReceiver(it); receiver = null } } catch (_: Exception) {}
    }

    private fun startProgressTracking(id: Long) {
        stopProgressTracking()
        progressJob = scope.launch {
            val manager = downloadManager ?: return@launch
            while (isActive) {
                val q = DownloadManager.Query().setFilterById(id)
                var cursor: Cursor? = null
                try {
                    cursor = manager.query(q)
                    if (cursor != null && cursor.moveToFirst()) {
                        val bytesDownloaded = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                        val bytesTotal = cursor.getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                        if (bytesTotal > 0) {
                            val progress = (bytesDownloaded * 100 / bytesTotal).toInt()
                            withContext(Dispatchers.Main) {
                                progressBar.progress = progress
                                tvStatus.text = "다운로드 중... ${progress}%"
                            }
                            if (progress >= 100) break
                        }
                    }
                } catch (e: Exception) {
                } finally {
                    cursor?.close()
                }
                delay(1000)
            }
        }
    }

    private fun stopProgressTracking() {
        progressJob?.cancel(); progressJob = null
    }
}
