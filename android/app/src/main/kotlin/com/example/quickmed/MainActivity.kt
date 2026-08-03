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
                        result.success(readManifestValue("com.google.android.geo.API_KEY"))
                    } catch (error: Exception) {
                        result.error(
                            "CONFIG_ERROR",
                            "Unable to read the Google Maps API key.",
                            error.message
                        )
                    }
                }

                "getGoogleRoutesApiKey" -> {
                    try {
                        val routesKey = readManifestValue(
                            "com.example.quickmed.ROUTES_API_KEY"
                        )
                        val mapsKey = readManifestValue(
                            "com.google.android.geo.API_KEY"
                        )
                        result.success(routesKey.ifBlank { mapsKey })
                    } catch (error: Exception) {
                        result.error(
                            "CONFIG_ERROR",
                            "Unable to read the Google Routes API key.",
                            error.message
                        )
                    }
                }

                "getAndroidAppIdentity" -> {
                    try {
                        result.success(
                            mapOf(
                                "packageName" to packageName,
                                "sha1Certificate" to getCurrentSha1Certificate()
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

    private fun readManifestValue(name: String): String {
        val applicationInfo = packageManager.getApplicationInfo(
            packageName,
            PackageManager.GET_META_DATA
        )
        return applicationInfo.metaData?.getString(name).orEmpty()
    }

    @Suppress("DEPRECATION")
    private fun getCurrentSha1Certificate(): String {
        val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNING_CERTIFICATES
            )
        } else {
            packageManager.getPackageInfo(
                packageName,
                PackageManager.GET_SIGNATURES
            )
        }

        // apkContentsSigners identifies the certificate that signed the APK
        // currently installed on this device. This avoids accidentally sending
        // an old certificate from signingCertificateHistory after key rotation.
        val signatureBytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            packageInfo.signingInfo
                ?.apkContentsSigners
                ?.firstOrNull()
                ?.toByteArray()
        } else {
            packageInfo.signatures
                ?.firstOrNull()
                ?.toByteArray()
        } ?: throw IllegalStateException(
            "No Android signing certificate was found."
        )

        val digest = MessageDigest.getInstance("SHA-1").digest(signatureBytes)
        return digest.joinToString(separator = "") { byte ->
            "%02X".format(byte.toInt() and 0xFF)
        }
    }
}
