package com.shaloon_dev.bizflow

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.shaloon_dev.bizflow/app_info"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAppVersion" -> {
                    try {
                        val pkgInfo = packageManager.getPackageInfo(packageName, 0)
                        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            pkgInfo.longVersionCode.toInt()
                        } else {
                            @Suppress("DEPRECATION")
                            pkgInfo.versionCode
                        }
                        result.success(
                            mapOf(
                                "version" to (pkgInfo.versionName ?: "1.0.3"),
                                "buildNumber" to versionCode,
                                "packageName" to packageName
                            )
                        )
                    } catch (e: Exception) {
                        result.success(
                            mapOf(
                                "version" to "1.0.3",
                                "buildNumber" to 4,
                                "packageName" to packageName
                            )
                        )
                    }
                }
                "openStore" -> {
                    val customUrl = call.argument<String>("url")
                    val pkg = packageName
                    try {
                        val marketIntent = Intent(
                            Intent.ACTION_VIEW,
                            Uri.parse("market://details?id=$pkg")
                        ).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(marketIntent)
                        result.success(true)
                    } catch (_: ActivityNotFoundException) {
                        try {
                            val webUrl = customUrl?.takeIf { it.isNotBlank() }
                                ?: "https://play.google.com/store/apps/details?id=$pkg"
                            val webIntent = Intent(
                                Intent.ACTION_VIEW,
                                Uri.parse(webUrl)
                            ).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(webIntent)
                            result.success(true)
                        } catch (_: Exception) {
                            result.success(false)
                        }
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
