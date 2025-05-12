import Flutter
import UIKit
import AVFoundation   // ← add this

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. Configure AVAudioSession for playback
    do {
      let session = AVAudioSession.sharedInstance()
      // .playback lets your app play even when the silent switch is on,
      // and lets you mix with other audio if you like.
      try session.setCategory(.playback, options: [.mixWithOthers])
      try session.setActive(true)
      print("AVAudioSession is set to playback")
    } catch {
      print("Failed to set AVAudioSession category: \(error)")
    }

    // 2. Register plugins and start Flutter
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
