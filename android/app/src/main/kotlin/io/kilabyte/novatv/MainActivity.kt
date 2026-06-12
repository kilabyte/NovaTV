package io.kilabyte.novatv

import android.app.PictureInPictureParams
import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.util.Rational
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Channel for platform-specific app info (currently: am-I-on-Android-TV?).
    private val platformChannel = "io.kilabyte.novatv/platform"

    /// Channel for system picture-in-picture. Flutter pushes playback
    /// eligibility and video size; native pushes PiP enter/exit/dismiss events.
    private val pipChannelName = "io.kilabyte.novatv/pip"

    private var pipChannel: MethodChannel? = null

    /// Whether a channel is currently playing, i.e. leaving the app should
    /// enter PiP. Updated from Flutter via updatePipParams.
    private var pipEligible = false

    /// Aspect ratio of the current video, defaulting to 16:9 until the
    /// decoder reports real dimensions.
    private var pipAspectRatio = Rational(16, 9)

    /// Set while the activity is in PiP mode and cleared on onResume (PiP
    /// expanded back to fullscreen). If onStop fires while this is still set
    /// AND the activity is no longer in PiP mode, the user dismissed the PiP
    /// window with the X button.
    private var inPip = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAndroidTV" -> result.success(isAndroidTv())
                    else -> result.notImplemented()
                }
            }

        pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pipChannelName)
        pipChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPipSupported" -> result.success(isPipSupported())
                "updatePipParams" -> {
                    val eligible = call.argument<Boolean>("eligible") ?: false
                    val width = call.argument<Int>("width") ?: 0
                    val height = call.argument<Int>("height") ?: 0
                    updatePipParams(eligible, width, height)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /// True if the current device's UI mode is "television" — i.e. the app
    /// is running on Android TV / Google TV. Used by the Flutter side to
    /// switch on a 10-foot UI variant.
    private fun isAndroidTv(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return uiModeManager.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }

    private fun isPipSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)

    private fun updatePipParams(eligible: Boolean, width: Int, height: Int) {
        if (!isPipSupported()) return
        pipEligible = eligible
        if (width > 0 && height > 0) {
            // The platform rejects aspect ratios outside 1:2.39-2.39:1 with an
            // IllegalArgumentException, so clamp ultrawide/tall video.
            val ratio = width.toFloat() / height.toFloat()
            pipAspectRatio = when {
                ratio > 2.39f -> Rational(239, 100)
                ratio < 1f / 2.39f -> Rational(100, 239)
                else -> Rational(width, height)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Android 12+: the system enters PiP automatically on home/swipe-up
            // when autoEnterEnabled is set, which is smoother than reacting in
            // onUserLeaveHint.
            try {
                setPictureInPictureParams(buildPipParams())
            } catch (_: IllegalStateException) {
                // Activity not attached to a task yet; params will be pushed
                // again on the next player state change.
            }
        }
    }

    private fun buildPipParams(): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder().setAspectRatio(pipAspectRatio)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(pipEligible)
        }
        return builder.build()
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Android 8-11 fallback: no auto-enter API, so enter PiP manually when
        // the user leaves the app while a channel is playing.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            pipEligible && isPipSupported()
        ) {
            try {
                enterPictureInPictureMode(buildPipParams())
            } catch (_: IllegalStateException) {
                // Device refuses PiP right now (e.g. locked); nothing to do.
            }
        }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        if (isInPictureInPictureMode) inPip = true
        pipChannel?.invokeMethod("pipChanged", isInPictureInPictureMode)
    }

    override fun onResume() {
        super.onResume()
        // Reaching resumed means the PiP window was expanded back into the
        // full app (or we never were in PiP).
        inPip = false
    }

    override fun onStop() {
        super.onStop()
        // Dismissed via the PiP window's X: mode-changed(false) fires first,
        // then onStop, without an onResume in between. Screen-off while in PiP
        // also stops the activity but keeps isInPictureInPictureMode true, so
        // it does NOT count as a dismissal.
        val stillInPipMode =
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && isInPictureInPictureMode
        if (inPip && !stillInPipMode) {
            inPip = false
            pipChannel?.invokeMethod("pipClosed", null)
        }
    }
}
