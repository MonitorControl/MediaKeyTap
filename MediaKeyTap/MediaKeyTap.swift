//
//  MediaKeyTap.swift
//  Castle
//
//  Created by Nicholas Hurden on 16/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa

public enum MediaKey {
  case playPause
  case previous
  case next
  case rewind
  case fastForward
  case brightnessUp
  case brightnessDown
  case volumeUp
  case volumeDown
  case mute
}

public enum KeyPressMode {
  case keyDown
  case keyUp
  case keyDownAndUp
}

public typealias Keycode = Int32
public typealias KeyFlags = Int32

public struct KeyEvent {
  public let keycode: Keycode
  public let keyFlags: KeyFlags
  public let keyPressed: Bool // Will be true after a keyDown and false after a keyUp
  public let keyRepeat: Bool
}

public protocol MediaKeyTapDelegate {
  func handle(mediaKey: MediaKey, event: KeyEvent?)
}

public class MediaKeyTap {
  let delegate: MediaKeyTapDelegate
  let mediaApplicationWatcher: MediaApplicationWatcher
  let internals: MediaKeyTapInternals
  let keyPressMode: KeyPressMode
  var observeBuiltIn: Bool = true
  var keysToWatch: [MediaKey] = [
    .playPause,
    .previous,
    .next,
    .rewind,
    .fastForward,
    .brightnessUp,
    .brightnessDown,
    .volumeUp,
    .volumeDown,
    .mute,
  ]

  var interceptMediaKeys: Bool {
    didSet {
      if self.interceptMediaKeys != oldValue {
        self.internals.enableTap(self.interceptMediaKeys)
      }
    }
  }

  // MARK: - Setup

  public init(delegate: MediaKeyTapDelegate, on mode: KeyPressMode = .keyDown, for keys: [MediaKey] = [], observeBuiltIn: Bool = true) {
    self.delegate = delegate
    self.interceptMediaKeys = false
    self.mediaApplicationWatcher = MediaApplicationWatcher()
    self.internals = MediaKeyTapInternals()
    self.keyPressMode = mode
    self.observeBuiltIn = observeBuiltIn
    if keys.count > 0 {
      self.keysToWatch = keys
    }
  }

  /// Activate the currently running application
  open func activate() {
    self.mediaApplicationWatcher.activate()
  }

  /// Start the key tap
  open func start() {
    self.mediaApplicationWatcher.delegate = self
    self.mediaApplicationWatcher.start()

    self.internals.delegate = self
    do {
      try self.internals.startWatchingMediaKeys()
    } catch let error as EventTapError {
      mediaApplicationWatcher.stop()
      print(error.description)
    } catch {}
  }

  /// Stop the key tap
  open func stop() {
    self.mediaApplicationWatcher.delegate = nil
    self.mediaApplicationWatcher.stop()

    self.internals.delegate = nil
    self.internals.stopWatchingMediaKeys()
  }

  public static func keycodeToMediaKey(_ keycode: Keycode) -> MediaKey? {
    switch keycode {
    case NX_KEYTYPE_PLAY: return .playPause
    case NX_KEYTYPE_PREVIOUS: return .previous
    case NX_KEYTYPE_NEXT: return .next
    case NX_KEYTYPE_REWIND: return .rewind
    case NX_KEYTYPE_FAST: return .fastForward
    case NX_KEYTYPE_BRIGHTNESS_UP: return .brightnessUp
    case NX_KEYTYPE_BRIGHTNESS_DOWN: return .brightnessDown
    case NX_KEYTYPE_SOUND_UP: return .volumeUp
    case NX_KEYTYPE_SOUND_DOWN: return .volumeDown
    case NX_KEYTYPE_MUTE: return .mute
    default: return nil
    }
  }

  public static func functionKeyCodeToMediaKey(_ keycode: Keycode) -> MediaKey? {
    switch keycode {
    case 113, 144: return .brightnessUp
    case 107, 145: return .brightnessDown
    default: return nil
    }
  }

  private func shouldNotifyDelegate(ofEvent event: KeyEvent) -> Bool {
    switch self.keyPressMode {
    case .keyDown:
      return event.keyPressed
    case .keyUp:
      return !event.keyPressed
    case .keyDownAndUp:
      return true
    }
  }
}

extension MediaKeyTap: MediaApplicationWatcherDelegate {
  func updateIsActiveMediaApp(_ active: Bool) {
    let keysMedia: [MediaKey] = [.playPause, .previous, .next, .rewind, .fastForward]
    if Set(self.keysToWatch).intersection(Set(keysMedia)).count > 0 {
      self.interceptMediaKeys = active
    }
  }

  // When a static whitelisted app starts, we need to restart the tap to ensure that
  // the dynamic whitelist is not overridden by the other app
  func whitelistedAppStarted() {
    do {
      try self.internals.restartTap()
    } catch let error as EventTapError {
      mediaApplicationWatcher.stop()
      print(error.description)
    } catch {}
  }
}

extension MediaKeyTap: MediaKeyTapInternalsDelegate {
  func updateInterceptMediaKeys(_ intercept: Bool) {
    self.interceptMediaKeys = intercept
  }

  func handle(keyEvent: KeyEvent, isFunctionKey: Bool) {
    if let key = isFunctionKey ? MediaKeyTap.functionKeyCodeToMediaKey(keyEvent.keycode) : MediaKeyTap.keycodeToMediaKey(keyEvent.keycode) {
      if self.shouldNotifyDelegate(ofEvent: keyEvent) {
        self.delegate.handle(mediaKey: key, event: keyEvent)
      }
    }
  }

  func isInterceptingMediaKeys() -> Bool {
    return self.interceptMediaKeys
  }
}
