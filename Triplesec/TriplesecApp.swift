import SwiftUI
import IOKit.hid
import ServiceManagement
import os

@main struct TriplesecApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}

private let log = Logger(subsystem: "gg.partyhat.triplesec", category: "main")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var tap: CFMachPort?
    private var lastButton = -1
    private var count = 0
    private var lastTime: TimeInterval = 0

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) != kIOHIDAccessTypeGranted {
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
        }
        if SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
        installTap()
    }

    private func installTap() {
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.otherMouseDown.rawValue),
            callback: callback,
            userInfo: refcon
        ) else {
            log.error("tap failed - grant Input Monitoring, then relaunch.")
            return
        }
        tap = t
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        log.info("armed")
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        let button = Int(event.getIntegerValueField(.mouseEventButtonNumber))
        guard type == .otherMouseDown, button >= 3 else { return }   // 0=L 1=R 2=mid, 3+=side

        let now = ProcessInfo.processInfo.systemUptime
        if button == lastButton && now - lastTime <= 0.5 {
            count += 1
        } else {
            count = 1
        }
        lastButton = button
        lastTime = now

        guard count >= 3 else { return }
        count = 0
        lastButton = -1
        lock()
    }

    // CGSession was removed in macOS 26; use login.framework's private lock.
    private func lock() {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/A/login", RTLD_NOW),
              let sym = dlsym(handle, "SACLockScreenImmediate") else { return }
        _ = unsafeBitCast(sym, to: (@convention(c) () -> Int32).self)()
    }
}

private let callback: CGEventTapCallBack = { _, type, event, refcon in
    if let refcon {
        Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
    }
    return Unmanaged.passUnretained(event)
}
