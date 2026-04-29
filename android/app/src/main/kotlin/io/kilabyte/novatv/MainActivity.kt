package io.kilabyte.novatv

import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    /// Channel for platform-specific app info (currently: am-I-on-Android-TV?).
    private val platformChannel = "io.kilabyte.novatv/platform"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, platformChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAndroidTV" -> result.success(isAndroidTv())
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
}
