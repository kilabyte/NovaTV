import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Native frame autosave. Complements the window_manager-based persistence
    // in WindowService and reduces first-launch flicker on macOS where the
    // OS can restore the window before Dart provider init completes.
    self.setFrameAutosaveName("NovaTVMain")

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
