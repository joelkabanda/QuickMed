package com.example.quickmed

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val configChannel = "quickmed/config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            configChannel
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getGoogleMapsApiKey" -> {
                    try {
                        val applicationInfo = packageManager.getApplicationInfo(
                            packageName,
                            PackageManager.GET_META_DATA
                        )
                        val apiKey = applicationInfo.metaData
                            ?.getString("com.google.android.geo.API_KEY")
                            .orEmpty()
                        result.success(apiKey)
                    } catch (error: Exception) {
                        result.error(
                            "CONFIG_ERROR",
                            "Unable to read Google Maps API key.",
                            error.message
                        )
                    }
                }
                "getAndroidAppIdentity" -> {
                    try {
                        result.success(
                            mapOf(
                                "packageName" to packageName,
                                "sha1Certificate" to getSha1Certificate()
                            )
                        )
                    } catch (error: Exception) {
                        result.error(
                            "IDENTITY_ERROR",
                            "Unable to read the Android package certificate.",
                            error.message
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun getSha1Certificate(): String {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES)
        }

        val signatureBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val signingInfo = packageInfo.signingInfo
            val signatures = if (signingInfo != null) {
                if (signingInfo.hasMultipleSigners()) signingInfo.apkContentsSigners
                else signingInfo.signingCertificateHistory
            } else null
            signatures?.firstOrNull()?.toByteArray()
        } else {
            packageInfo.signatures?.firstOrNull()?.toByteArray()
        } ?: throw Exception("No signatures found")

        val digest = MessageDigest.getInstance("SHA-1").digest(signatureBytes)
        return digest.joinToString(separator = "") { byte -> "%02X".format(byte.toInt() and 0xFF) }
    }
}
