package com.leoon.offnote.offnote

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaMuxer
import android.net.Uri
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer

class MainActivity : FlutterActivity() {
    private var pendingBackupPickResult: MethodChannel.Result? = null
    private var pendingResourcePickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "offnote/app_update"
        ).setMethodCallHandler { call, result ->
            if (call.method != "installApk") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            if (path.isNullOrBlank()) {
                result.error("missing_path", "APK path is empty", null)
                return@setMethodCallHandler
            }

            try {
                val file = File(path)
                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file
                )
                val intent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "application/vnd.android.package-archive")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                result.success(null)
            } catch (error: Exception) {
                result.error("install_failed", error.message, null)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "offnote/video_tools"
        ).setMethodCallHandler { call, result ->
            if (call.method != "trimVideo") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val inputPath = call.argument<String>("inputPath")
            val outputPath = call.argument<String>("outputPath")
            val startMs = call.argument<Number>("startMs")?.toLong()
            val endMs = call.argument<Number>("endMs")?.toLong()
            if (inputPath.isNullOrBlank() || outputPath.isNullOrBlank() || startMs == null || endMs == null) {
                result.error("bad_args", "Missing trimVideo arguments", null)
                return@setMethodCallHandler
            }
            if (endMs <= startMs) {
                result.error("bad_range", "End time must be after start time", null)
                return@setMethodCallHandler
            }

            Thread {
                try {
                    trimVideo(inputPath, outputPath, startMs, endMs)
                    runOnUiThread { result.success(null) }
                } catch (error: Exception) {
                    runOnUiThread {
                        result.error("trim_failed", error.message, null)
                    }
                }
            }.start()
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "offnote/backup_files"
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickBackupFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingBackupPickResult != null) {
                result.error("already_picking", "A backup file picker is already open", null)
                return@setMethodCallHandler
            }
            pendingBackupPickResult = result
            try {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf("application/zip", "application/octet-stream", "*/*")
                    )
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivityForResult(intent, BACKUP_PICK_REQUEST_CODE)
            } catch (error: Exception) {
                pendingBackupPickResult = null
                result.error("pick_failed", error.message, null)
            }
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "offnote/resource_files"
        ).setMethodCallHandler { call, result ->
            val mimeType = when (call.method) {
                "pickImageResourceFile" -> "image/*"
                "pickVideoResourceFile" -> "video/*"
                else -> null
            }
            if (mimeType == null) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingResourcePickResult != null) {
                result.error("already_picking", "A resource file picker is already open", null)
                return@setMethodCallHandler
            }
            pendingResourcePickResult = result
            try {
                val requestCode = if (mimeType.startsWith("image/")) {
                    RESOURCE_IMAGE_PICK_REQUEST_CODE
                } else {
                    RESOURCE_VIDEO_PICK_REQUEST_CODE
                }
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = mimeType
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                startActivityForResult(intent, requestCode)
            } catch (error: Exception) {
                pendingResourcePickResult = null
                result.error("pick_failed", error.message, null)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == BACKUP_PICK_REQUEST_CODE) {
            val result = pendingBackupPickResult ?: return
            pendingBackupPickResult = null
            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }
            val uri = data?.data
            if (uri == null) {
                result.success(null)
                return
            }
            try {
                result.success(copyPickedBackupToCache(uri))
            } catch (error: Exception) {
                result.error("copy_failed", error.message, null)
            }
            return
        }
        if (
            requestCode == RESOURCE_IMAGE_PICK_REQUEST_CODE ||
            requestCode == RESOURCE_VIDEO_PICK_REQUEST_CODE
        ) {
            val result = pendingResourcePickResult ?: return
            pendingResourcePickResult = null
            if (resultCode != Activity.RESULT_OK) {
                result.success(null)
                return
            }
            val uri = data?.data
            if (uri == null) {
                result.success(null)
                return
            }
            try {
                result.success(copyPickedResourceToCache(uri))
            } catch (error: Exception) {
                result.error("copy_failed", error.message, null)
            }
        }
    }

    private fun copyPickedBackupToCache(uri: Uri): String {
        val importsDir = File(cacheDir, "backup-imports")
        importsDir.mkdirs()
        val name = sanitizeFileName(queryDisplayName(uri) ?: "imported.offnote-backup")
        val target = File(importsDir, "${System.currentTimeMillis()}-$name")
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalArgumentException("Cannot open selected file")
            }
            target.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return target.absolutePath
    }

    private fun copyPickedResourceToCache(uri: Uri): String {
        val importsDir = File(cacheDir, "resource-imports")
        importsDir.mkdirs()
        val name = sanitizeFileName(queryDisplayName(uri) ?: "resource")
        val target = File(importsDir, "${System.currentTimeMillis()}-$name")
        contentResolver.openInputStream(uri).use { input ->
            if (input == null) {
                throw IllegalArgumentException("Cannot open selected file")
            }
            target.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return target.absolutePath
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            if (cursor != null && cursor.moveToFirst()) {
                cursor.getString(0)
            } else {
                null
            }
        } finally {
            cursor?.close()
        }
    }

    private fun sanitizeFileName(name: String): String {
        return name.replace(Regex("[^A-Za-z0-9._-]"), "_")
    }

    private fun trimVideo(inputPath: String, outputPath: String, startMs: Long, endMs: Long) {
        val outputFile = File(outputPath)
        outputFile.parentFile?.mkdirs()
        if (outputFile.exists()) {
            outputFile.delete()
        }

        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null
        try {
            extractor.setDataSource(inputPath)
            val trackMap = mutableMapOf<Int, Int>()
            var maxInputSize = 1024 * 1024
            for (trackIndex in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(trackIndex)
                val mime = format.getString(android.media.MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/") && !mime.startsWith("audio/")) {
                    continue
                }
                if (format.containsKey(android.media.MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    maxInputSize = maxOf(
                        maxInputSize,
                        format.getInteger(android.media.MediaFormat.KEY_MAX_INPUT_SIZE)
                    )
                }
                extractor.selectTrack(trackIndex)
                if (muxer == null) {
                    muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
                }
                trackMap[trackIndex] = muxer!!.addTrack(format)
            }
            val activeMuxer = muxer ?: throw IllegalStateException("No audio or video tracks found")
            activeMuxer.start()

            val startUs = startMs * 1000
            val endUs = endMs * 1000
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            val buffer = ByteBuffer.allocate(maxInputSize)
            val info = MediaCodec.BufferInfo()
            while (true) {
                val sourceTrack = extractor.sampleTrackIndex
                if (sourceTrack < 0) {
                    break
                }
                val muxerTrack = trackMap[sourceTrack]
                if (muxerTrack == null) {
                    extractor.advance()
                    continue
                }
                val sampleTimeUs = extractor.sampleTime
                if (sampleTimeUs > endUs) {
                    break
                }
                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) {
                    break
                }
                info.set(
                    0,
                    sampleSize,
                    maxOf(0, sampleTimeUs - startUs),
                    extractor.sampleFlags
                )
                activeMuxer.writeSampleData(muxerTrack, buffer, info)
                extractor.advance()
            }
        } finally {
            try {
                muxer?.stop()
            } catch (_: Exception) {
            }
            try {
                muxer?.release()
            } catch (_: Exception) {
            }
            extractor.release()
        }
    }

    companion object {
        private const val BACKUP_PICK_REQUEST_CODE = 42031
        private const val RESOURCE_IMAGE_PICK_REQUEST_CODE = 42041
        private const val RESOURCE_VIDEO_PICK_REQUEST_CODE = 42042
    }
}
