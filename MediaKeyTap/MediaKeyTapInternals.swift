//
//  MediaKeyTapInternals.swift
//  Castle
//
//  A wrapper around the C APIs required for a CGEventTap
//
//  Created by Nicholas Hurden on 18/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa
import CoreGraphics

enum EventTapError: Error {
    case eventTapCreationFailure
    case runLoopSourceCreationFailure
}

extension EventTapError: CustomStringConvertible {
    var description: String {
        switch self {
        case .eventTapCreationFailure: return "Event tap creation failed: is your application sandboxed?"
        case .runLoopSourceCreationFailure: return "Runloop source creation failed"
        }
    }
}

func mainScreen() -> NSScreen? {
    let mouseLocation = NSEvent.mouseLocation
    let screens = NSScreen.screens
    let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })

    return screenWithMouse
}

protocol MediaKeyTapInternalsDelegate: class {
    var keysToWatch: [MediaKey] { get set }
    var observeBuiltIn: Bool { get set }
    func updateInterceptMediaKeys(_ intercept: Bool)
    func handle(keyEvent: KeyEvent, isFunctionKey: Bool, modifiers: NSEvent.ModifierFlags?)
    func isInterceptingMediaKeys() -> Bool
}

class MediaKeyTapInternals {
    typealias EventTapCallback = @convention(block) (CGEventType, CGEvent) -> CGEvent?

    weak var delegate: MediaKeyTapInternalsDelegate?
    var keyEventPort: CFMachPort?
    var runLoopSource: CFRunLoopSource?
    var callback: EventTapCallback?
    var runLoopQueue: DispatchQueue?
    var runLoop: CFRunLoop?

    deinit {
        stopWatchingMediaKeys()
    }

    /**
     Enable/Disable the underlying tap
     */
    func enableTap(_ onOff: Bool) {
        if keyEventPort != nil, let runLoop = self.runLoop {
            CFRunLoopPerformBlock(runLoop, CFRunLoopMode.commonModes as CFTypeRef) { [weak self] in
                guard let port = self?.keyEventPort else { return }
                CGEvent.tapEnable(tap: port, enable: onOff)
            }
            CFRunLoopWakeUp(runLoop)
        }
    }

    /**
     Restart the tap, placing it in front of existing taps
     */
    func restartTap() throws {
        stopWatchingMediaKeys()
        try startWatchingMediaKeys(restart: true)
    }

    func startWatchingMediaKeys(restart: Bool = false) throws {
        let eventTapCallback: EventTapCallback = { [weak self] type, event in
            guard let self = self else { return event }
            if type == .tapDisabledByTimeout {
                if let port = self.keyEventPort {
                    CGEvent.tapEnable(tap: port, enable: true)
                }
                return event
            } else if type == .tapDisabledByUserInput {
                return event
            }

            return DispatchQueue.main.sync {
                self.handle(event: event, ofType: type)
            }
        }

        try startKeyEventTap(callback: eventTapCallback, restart: restart)
        callback = eventTapCallback
    }

    func stopWatchingMediaKeys() {
        if let runLoopSource = self.runLoopSource {
            CFRunLoopSourceInvalidate(runLoopSource)
        }
        if let runLoop = self.runLoop {
            CFRunLoopStop(runLoop)
        }
        if let keyEventPort = self.keyEventPort {
            CFMachPortInvalidate(keyEventPort)
        }
    }

    private func handle(event: CGEvent, ofType type: CGEventType) -> CGEvent? {
        if type == .keyDown {
            let keycode: Int64 = event.getIntegerValueField(.keyboardEventKeycode)
            guard let mediaKey = MediaKeyTap.functionKeyCodeToMediaKey(Int32(keycode)) else { return event }
            if delegate?.keysToWatch.contains(mediaKey) ?? false {
                if !(delegate?.observeBuiltIn ?? true) {
                    if let id = mainScreen()?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                        if CGDisplayIsBuiltin(id) != 0 {
                            return event
                        }
                    }
                }

                delegate?.handle(
                    keyEvent: KeyEvent(keycode: Int32(keycode), keyFlags: 0, keyPressed: true, keyRepeat: false),
                    isFunctionKey: true,
                    modifiers: NSEvent(cgEvent: event)?.modifierFlags
                )

                return nil
            } else {
                return event
            }
        }

        if let nsEvent = NSEvent(cgEvent: event) {
            guard let mediaKey = MediaKeyTap.keycodeToMediaKey(nsEvent.keyEvent.keycode) else { return event }
            guard type.rawValue == UInt32(NX_SYSDEFINED),
                  nsEvent.isMediaKeyEvent,
                  delegate?.keysToWatch.contains(mediaKey) ?? false,
                  delegate?.isInterceptingMediaKeys() ?? false
            else { return event }

            if delegate?.observeBuiltIn ?? true == false {
                if let id = mainScreen()?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
                    if CGDisplayIsBuiltin(id) != 0 {
                        return event
                    }
                }
            }
            delegate?.handle(keyEvent: nsEvent.keyEvent, isFunctionKey: false, modifiers: nsEvent.modifierFlags)

            return nil
        }

        return event
    }

    private func startKeyEventTap(callback: @escaping EventTapCallback, restart: Bool) throws {
        // On a restart we don't want to interfere with the application watcher
        if !restart {
            delegate?.updateInterceptMediaKeys(true)
        }

        keyEventPort = keyCaptureEventTapPort(callback: callback)
        guard let port = keyEventPort else { throw EventTapError.eventTapCreationFailure }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorSystemDefault, port, 0)
        guard let source = runLoopSource else { throw EventTapError.runLoopSourceCreationFailure }

        let queue = DispatchQueue(label: "MediaKeyTap Runloop", attributes: [])
        runLoopQueue = queue

        queue.async { [weak self] in
            guard let self = self else { return }
            self.runLoop = CFRunLoopGetCurrent()
            CFRunLoopAddSource(self.runLoop, source, CFRunLoopMode.commonModes)
            CFRunLoopRun()
        }
    }

    private func keyCaptureEventTapPort(callback: @escaping EventTapCallback) -> CFMachPort? {
        let cCallback: CGEventTapCallBack = { _, type, event, refcon in
            let innerBlock = unsafeBitCast(refcon, to: EventTapCallback.self)
            return innerBlock(type, event).map(Unmanaged.passUnretained)
        }

        let refcon = unsafeBitCast(callback, to: UnsafeMutableRawPointer.self)

        return CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << NX_KEYDOWN) | CGEventMask(1 << NX_SYSDEFINED),
            callback: cCallback,
            userInfo: refcon
        )
    }
}
