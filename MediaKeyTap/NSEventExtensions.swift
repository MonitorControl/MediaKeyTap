//
//  NSEventExtensions.swift
//  MediaKeyTap
//
//  Created by Nicholas Hurden on 28/09/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import AppKit

extension NSEvent {
  var isKeyEvent: Bool {
    subtype.rawValue == 8
  }

  var keycode: Keycode {
    Keycode((data1 & 0xFFFF_0000) >> 16)
  }

  var keyEvent: KeyEvent {
    let keyFlags = KeyFlags(data1 & 0x0000_FFFF)
    let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA
    let keyRepeat = (keyFlags & 0x1) == 0x1

    return KeyEvent(keycode: self.keycode, keyFlags: keyFlags, keyPressed: keyPressed, keyRepeat: keyRepeat)
  }

  var isMediaKeyEvent: Bool {
    let mediaKeys = [NX_KEYTYPE_PLAY, NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST, NX_KEYTYPE_REWIND, NX_KEYTYPE_BRIGHTNESS_UP, NX_KEYTYPE_BRIGHTNESS_DOWN, NX_KEYTYPE_SOUND_UP, NX_KEYTYPE_SOUND_DOWN, NX_KEYTYPE_MUTE]
    return self.isKeyEvent && mediaKeys.contains(self.keycode)
  }
}
