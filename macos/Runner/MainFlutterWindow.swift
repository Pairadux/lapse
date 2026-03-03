import Cocoa
import FlutterMacOS

/// Custom NSWindow subclass that suppresses macOS NSBeep for unhandled key
/// events. Flutter's FlutterViewController processes keyboard input before
/// events reach keyDown, so text fields and shortcuts are unaffected.
class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  override func keyDown(with event: NSEvent) {
    // Intentionally empty — prevents NSBeep for key events that
    // propagate past Flutter without being handled by any widget.
  }
}
