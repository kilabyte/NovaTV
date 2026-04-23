import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// Channel used to bridge native menu/media key events to Flutter.
  private var menuChannel: FlutterMethodChannel?

  // Keep the app resident in the dock when the user closes the last window.
  // Media players are expected to behave this way — closing the window should
  // hide it, not terminate the process. Reopen via dock click is handled by
  // applicationShouldHandleReopen below.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  // When the user clicks the dock icon (or uses Finder "Open") after closing
  // the window, re-show the Flutter window instead of creating a new instance.
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

    // Set up the menu bridge channel so the Flutter side can be notified when
    // the user picks Preferences from the menu bar.
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      menuChannel = FlutterMethodChannel(
        name: "io.kilabyte.novatv/menu",
        binaryMessenger: controller.engine.binaryMessenger
      )
    }

    wirePreferencesMenuItem()
  }

  /// The Flutter macOS project template ships with a stock "Preferences…"
  /// menu item that isn't connected to anything. Find it in the Main menu
  /// and route its action to [openPreferences:] so it navigates to the
  /// Flutter Settings route instead of silently doing nothing.
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
}
