package com.adbsmalltech.adbapp

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import android.os.Environment
import android.webkit.MimeTypeMap

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.adbsmalltech.adbapp/share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "shareFilesToWhatsApp" -> {
                    val filePaths = call.argument<List<String>>("filePaths")
                    val text = call.argument<String>("text") ?: ""
                    
                    if (filePaths != null) {
                        shareFilesToWhatsApp(filePaths, text)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENTS", "File paths are required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun shareFilesToWhatsApp(filePaths: List<String>, text: String) {
        try {
            println("ShareFiles: Received ${filePaths.size} file paths")
            filePaths.forEachIndexed { index, path ->
                println("ShareFiles: File $index: $path")
                println("ShareFiles: File exists: ${File(path).exists()}")
            }
            
            // Use Downloads directory for temporary sharing (more accessible)
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val shareDir = File(downloadsDir, "SchoolApp_Share")
            
            // Clean old files first
            if (shareDir.exists()) {
                shareDir.listFiles()?.forEach { it.delete() }
            } else {
                shareDir.mkdirs()
            }
            
            println("ShareFiles: Using share directory: ${shareDir.absolutePath}")
            
            val tempFiles = mutableListOf<File>()
            filePaths.forEach { originalPath ->
                try {
                    val originalFile = File(originalPath)
                    if (originalFile.exists()) {
                        val tempFile = File(shareDir, originalFile.name)
                        copyFile(originalFile, tempFile)
                        tempFiles.add(tempFile)
                        println("ShareFiles: Copied to temp file: ${tempFile.absolutePath}")
                    } else {
                        println("ShareFiles: Original file does not exist: $originalPath")
                    }
                } catch (e: Exception) {
                    println("ShareFiles: Error copying file $originalPath: ${e.message}")
                    e.printStackTrace()
                }
            }
            
            if (tempFiles.isEmpty()) {
                println("ShareFiles: No temp files created, cannot share")
                return
            }
            
            println("ShareFiles: Created ${tempFiles.size} temp files for sharing")
            
            val shareIntent = Intent().apply {
                if (tempFiles.size == 1) {
                    action = Intent.ACTION_SEND
                    val file = tempFiles[0]
                    val uri = Uri.fromFile(file) // Use file:// URI for public directory
                    
                    // Set MIME type based on file extension
                    val mimeType = getMimeType(file.absolutePath)
                    type = mimeType
                    
                    putExtra(Intent.EXTRA_STREAM, uri)
                    println("ShareFiles: Single file URI: $uri, MIME: $mimeType")
                } else {
                    action = Intent.ACTION_SEND_MULTIPLE
                    type = "*/*"
                    val uris = ArrayList<Uri>()
                    tempFiles.forEach { file ->
                        val uri = Uri.fromFile(file) // Use file:// URI for public directory
                        uris.add(uri)
                        println("ShareFiles: Multiple file URI: $uri")
                    }
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                    println("ShareFiles: Multiple files intent created with ${uris.size} URIs")
                }
                putExtra(Intent.EXTRA_TEXT, text)
                setPackage("com.whatsapp")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            // Check if WhatsApp is installed, otherwise use general share
            val packageManager = packageManager
            if (shareIntent.resolveActivity(packageManager) != null) {
                startActivity(shareIntent)
                println("ShareFiles: Started WhatsApp share intent")
            } else {
                // Fallback to general share if WhatsApp is not installed
                shareIntent.setPackage(null)
                val chooser = Intent.createChooser(shareIntent, "Share files")
                startActivity(chooser)
                println("ShareFiles: WhatsApp not found, started general share chooser")
            }
        } catch (e: Exception) {
            println("ShareFiles: Exception in shareFilesToWhatsApp: ${e.message}")
            e.printStackTrace()
            // Final fallback
            shareFilesDirectly(filePaths, text)
        }
    }
    
    private fun shareFilesDirectly(filePaths: List<String>, text: String) {
        try {
            val shareIntent = Intent().apply {
                if (filePaths.size == 1) {
                    action = Intent.ACTION_SEND
                    type = "*/*"
                    val file = File(filePaths[0])
                    val uri = FileProvider.getUriForFile(this@MainActivity, "${packageName}.fileprovider", file)
                    putExtra(Intent.EXTRA_STREAM, uri)
                } else {
                    action = Intent.ACTION_SEND_MULTIPLE
                    type = "*/*"
                    val uris = ArrayList<Uri>()
                    filePaths.forEach { path ->
                        val file = File(path)
                        val uri = FileProvider.getUriForFile(this@MainActivity, "${packageName}.fileprovider", file)
                        uris.add(uri)
                    }
                    putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
                }
                putExtra(Intent.EXTRA_TEXT, text)
                setPackage("com.whatsapp")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }

            val packageManager = packageManager
            if (shareIntent.resolveActivity(packageManager) != null) {
                startActivity(shareIntent)
            } else {
                shareIntent.setPackage(null)
                val chooser = Intent.createChooser(shareIntent, "Share files")
                startActivity(chooser)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    private fun copyFile(sourceFile: File, destFile: File) {
        FileInputStream(sourceFile).use { input ->
            FileOutputStream(destFile).use { output ->
                input.copyTo(output)
            }
        }
    }
    
    private fun getMimeType(filePath: String): String {
        val extension = MimeTypeMap.getFileExtensionFromUrl(filePath)
        return when (extension.lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "mp4" -> "video/mp4"
            "mov" -> "video/quicktime"
            "3gp" -> "video/3gpp"
            "mkv" -> "video/x-matroska"
            else -> MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"
        }
    }
}
