import Cocoa
import FlutterMacOS
import MediaPlayer

@main
class AppDelegate: FlutterAppDelegate {
  /// Channel used to bridge native menu/media key events to Flutter.
  private var menuChannel: FlutterMethodChannel?
  /// Channel for Now Playing + MPRemoteCommandCenter interactions.
  private var nowPlayingChannel: FlutterMethodChannel?

  // Keep the app resident in the dock when the user closes the last window.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      for window in sender.windows where window is MainFlutterWindow {
        window.makeKeyAndOrderFront(nil)
      }
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // A single-window app — native tab bar would create a broken state.
    NSWindow.allowsAutomaticWindowTabbing = false

    super.applicationDidFinishLaunching(notification)

    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      menuChannel = FlutterMethodChannel(
        name: "io.kilabyte.novatv/menu",
        binaryMessenger: controller.engine.binaryMessenger
      )

      nowPlayingChannel = FlutterMethodChannel(
        name: "io.kilabyte.novatv/nowplaying",
        binaryMessenger: controller.engine.binaryMessenger
      )
      nowPlayingChannel?.setMethodCallHandler { [weak self] call, result in
        self?.handleNowPlayingCall(call, result: result)
      }
    }

    wirePreferencesMenuItem()
    setupRemoteCommands()
  }

  private func wirePreferencesMenuItem() {
    guard let mainMenu = NSApp.mainMenu else { return }
    for menu in mainMenu.items.compactMap({ $0.submenu }) {
      for item in menu.items where item.title.lowercased().contains("preference") {
        item.target = self
        item.action = #selector(openPreferences(_:))
      }
    }
  }

  @objc func openPreferences(_ sender: Any?) {
    menuChannel?.invokeMethod("openSettings", arguments: nil)
  }

  // MARK: - Now Playing / Media keys

  /// Wire system media-key events (play/pause on keyboard and AirPods,
  /// Control Center, Lock Screen) to the Flutter side.
  private func setupRemoteCommands() {
    let center = MPRemoteCommandCenter.shared()

    center.playCommand.isEnabled = true
    center.playCommand.addTarget { [weak self] _ in
      self?.nowPlayingChannel?.invokeMethod("play", arguments: nil)
      return .success
    }

    center.pauseCommand.isEnabled = true
    center.pauseCommand.addTarget { [weak self] _ in
      self?.nowPlayingChannel?.invokeMethod("pause", arguments: nil)
      return .success
    }

    center.togglePlayPauseCommand.isEnabled = true
    center.togglePlayPauseCommand.addTarget { [weak self] _ in
      self?.nowPlayingChannel?.invokeMethod("togglePlayPause", arguments: nil)
      return .success
    }

    center.stopCommand.isEnabled = true
    center.stopCommand.addTarget { [weak self] _ in
      self?.nowPlayingChannel?.invokeMethod("stop", arguments: nil)
      return .success
    }
  }

  /// Inbound messages from Flutter: update Now Playing info or clear it.
  private func handleNowPlayingCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "update":
      let args = call.arguments as? [String: Any] ?? [:]
      var info: [String: Any] = [:]
      if let title = args["title"] as? String { info[MPMediaItemPropertyTitle] = title }
      if let subtitle = args["subtitle"] as? String { info[MPMediaItemPropertyArtist] = subtitle }
      if let isPlaying = args["isPlaying"] as? Bool {
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
      }
      MPNowPlayingInfoCenter.default().nowPlayingInfo = info
      MPNowPlayingInfoCenter.default().playbackState = (args["isPlaying"] as? Bool ?? true) ? .playing : .paused
      result(nil)
    case "clear":
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
      MPNowPlayingInfoCenter.default().playbackState = .stopped
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
