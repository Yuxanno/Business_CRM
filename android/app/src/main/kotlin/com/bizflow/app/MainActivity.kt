package com.bizflow.app

import android.os.Build
import android.os.Bundle
import android.view.Display
import android.view.Surface
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        capRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        // Some OEM ROMs reset display mode when the app returns to foreground.
        capRefreshRate()
    }

    override fun onPostResume() {
        super.onPostResume()
        applySurfaceFrameRateCap(window?.decorView)
    }

    /**
     * Caps the display (and therefore Flutter's vsync) at 60 Hz.
     * On 90/120/144 Hz phones Flutter would otherwise try to render up to
     * 120 frames per second, overloading weaker CPUs/GPUs and causing jank
     * and heat. 60 Hz is smooth and stable on every device.
     */
    private fun capRefreshRate() {
        try {
            val display: Display? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                this.display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            }
            if (display == null) return

            val attrs = window.attributes
            attrs.preferredRefreshRate = MAX_FPS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val current = display.mode
                val sameResolutionModes = display.supportedModes.filter {
                    it.physicalWidth == current.physicalWidth &&
                        it.physicalHeight == current.physicalHeight
                }
                val capped = sameResolutionModes
                    .filter { it.refreshRate in MIN_FPS..(MAX_FPS + 1f) }
                    .maxByOrNull { it.refreshRate }
                    ?: sameResolutionModes
                        .filter { it.refreshRate <= MAX_FPS + 1f }
                        .maxByOrNull { it.refreshRate }

                if (capped != null) {
                    attrs.preferredDisplayModeId = capped.modeId
                }
            }
            window.attributes = attrs
            applySurfaceFrameRateCap(window?.decorView)
        } catch (_: Throwable) {
            // Never crash because of a display-mode request.
        }
    }

    private fun applySurfaceFrameRateCap(root: View?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || root == null) return
        try {
            if (root is SurfaceView) {
                root.holder?.surface?.let { surface ->
                    if (surface.isValid) {
                        surface.setFrameRate(
                            MAX_FPS,
                            Surface.FRAME_RATE_COMPATIBILITY_DEFAULT
                        )
                    }
                }
            } else if (root is ViewGroup) {
                for (i in 0 until root.childCount) {
                    applySurfaceFrameRateCap(root.getChildAt(i))
                }
            }
        } catch (_: Throwable) {
        }
    }

    companion object {
        private const val MIN_FPS = 30f
        private const val MAX_FPS = 60f
    }
}
