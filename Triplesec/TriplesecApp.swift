import AppKit
import CoreGraphics
import OSLog
import ServiceManagement

@main
private enum TriplesecApplication {
  private static let delegate = AppDelegate()

  static func main() {
    let application = NSApplication.shared
    application.delegate = delegate
    application.run()
  }
}

private let log = Logger(subsystem: "gg.partyhat.triplesec", category: "app")

private final class AppDelegate: NSObject, NSApplicationDelegate {
  private var eventTap: CFMachPort?
  private var eventTapSource: CFRunLoopSource?
  private var gesture = LockGesture()
  private lazy var screenLocker = ScreenLocker()

  func applicationDidFinishLaunching(_: Notification) {
    guard requestInputMonitoringAccess() else {
      NSApplication.shared.terminate(nil)
      return
    }

    registerLoginItem()
    installEventTap()
  }

  func applicationWillTerminate(_: Notification) {
    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }
    if let eventTapSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
    }
  }

  private func registerLoginItem() {
    let loginItem = SMAppService.mainApp

    switch loginItem.status {
    case .enabled:
      return
    case .notRegistered:
      do {
        try loginItem.register()
        log.info("Registered as a login item.")
      } catch {
        log.error(
          "Could not register as a login item: \(error.localizedDescription, privacy: .public)")
      }
    case .requiresApproval:
      log.notice("Login item needs approval in System Settings.")
    case .notFound:
      log.error("Could not find the app's login-item service.")
    @unknown default:
      log.error("Encountered an unknown login-item status.")
    }
  }

  private func requestInputMonitoringAccess() -> Bool {
    if CGPreflightListenEventAccess() {
      return true
    }

    if CGRequestListenEventAccess() {
      return true
    }

    openInputMonitoringSettings()
    log.notice("Input Monitoring is required; grant access, then reopen Triplesec.")
    return false
  }

  private func openInputMonitoringSettings() {
    let settingsURL = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    )!
    NSWorkspace.shared.open(settingsURL)
  }

  private func installEventTap() {
    let eventMask = CGEventMask(1) << CGEventType.otherMouseDown.rawValue
    let refcon = Unmanaged.passUnretained(self).toOpaque()

    guard
      let eventTap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: eventMask,
        callback: eventTapCallback,
        userInfo: refcon
      )
    else {
      log.error("Could not create the mouse event tap.")
      return
    }

    let source = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
    self.eventTap = eventTap
    eventTapSource = source
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: eventTap, enable: true)
    log.info("Listening for the lock gesture.")
  }

  func handleEvent(type: CGEventType, event: CGEvent) {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
        log.notice("Mouse event tap was disabled and has been re-enabled.")
      }
      return
    }

    guard type == .otherMouseDown else {
      return
    }

    let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
    guard button >= LockGesture.minimumButtonNumber else {
      return
    }

    let time = ProcessInfo.processInfo.systemUptime
    guard gesture.recordPress(of: button, at: time) else {
      return
    }

    screenLocker.lock()
  }
}

private struct LockGesture {
  static let minimumButtonNumber = 3
  static let requiredPresses = 3
  static let maximumInterval: TimeInterval = 0.5

  private var lastButton: Int?
  private var lastPressTime: TimeInterval?
  private var pressCount = 0

  mutating func recordPress(of button: Int, at time: TimeInterval) -> Bool {
    let continuesSequence =
      button == lastButton
      && lastPressTime.map { time - $0 <= Self.maximumInterval } == true

    pressCount = continuesSequence ? pressCount + 1 : 1
    lastButton = button
    lastPressTime = time

    guard pressCount >= Self.requiredPresses else {
      return false
    }

    reset()
    return true
  }

  private mutating func reset() {
    lastButton = nil
    lastPressTime = nil
    pressCount = 0
  }
}

private final class ScreenLocker {
  private typealias LockScreenFunction = @convention(c) () -> Int32

  private let frameworkHandle: UnsafeMutableRawPointer?
  private let lockScreenFunction: LockScreenFunction?

  init() {
    let frameworkPath = "/System/Library/PrivateFrameworks/login.framework/login"

    guard let handle = dlopen(frameworkPath, RTLD_NOW) else {
      frameworkHandle = nil
      lockScreenFunction = nil
      log.error("Could not open login.framework: \(Self.dynamicLoaderError, privacy: .public)")
      return
    }

    guard let symbol = dlsym(handle, "SACLockScreenImmediate") else {
      let loaderError = Self.dynamicLoaderError
      dlclose(handle)
      frameworkHandle = nil
      lockScreenFunction = nil
      log.error("Could not find the screen-lock function: \(loaderError, privacy: .public)")
      return
    }

    frameworkHandle = handle
    lockScreenFunction = unsafeBitCast(symbol, to: LockScreenFunction.self)
  }

  deinit {
    if let frameworkHandle {
      dlclose(frameworkHandle)
    }
  }

  func lock() {
    guard let lockScreenFunction else {
      log.error("Screen locking is unavailable.")
      return
    }

    _ = lockScreenFunction()
  }

  private static var dynamicLoaderError: String {
    guard let message = dlerror() else {
      return "unknown dynamic-loader error"
    }
    return String(cString: message)
  }
}

private let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
  guard let refcon else {
    return Unmanaged.passUnretained(event)
  }

  let delegate = Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue()
  delegate.handleEvent(type: type, event: event)
  return Unmanaged.passUnretained(event)
}
