//
//  ViewController.swift
//  MediaKeyTapExample
//
//  Created by Nicholas Hurden on 22/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Cocoa
import MediaKeyTap

class ViewController: NSViewController {
  @IBOutlet var playPauseLabel: NSTextField!
  @IBOutlet var previousLabel: NSTextField!
  @IBOutlet var rewindLabel: NSTextField!
  @IBOutlet var nextLabel: NSTextField!
  @IBOutlet var fastForwardLabel: NSTextField!

  var mediaKeyTap: MediaKeyTap?

  override func viewDidLoad() {
    super.viewDidLoad()

    self.mediaKeyTap = MediaKeyTap(delegate: self, on: .keyDownAndUp)
    self.mediaKeyTap?.start()
  }

  func toggleLabel(_ label: NSTextField, enabled: Bool) {
    label.textColor = enabled ? NSColor.green : NSColor.textColor
  }
}

extension ViewController: MediaKeyTapDelegate {
  func handle(mediaKey: MediaKey, event: KeyEvent?, modifiers: NSEvent.ModifierFlags?) {
    if modifiers?.isSuperset(of: NSEvent.ModifierFlags([.shift, .option])) ?? false {
      print("Shift + Option pressed")
    }
    switch mediaKey {
    case .playPause:
      print("Play/pause pressed")
      self.toggleLabel(self.playPauseLabel, enabled: event?.keyPressed ?? false)
    case .previous:
      print("Previous pressed")
      self.toggleLabel(self.previousLabel, enabled: event?.keyPressed ?? false)
    case .rewind:
      print("Rewind pressed")
      self.toggleLabel(self.rewindLabel, enabled: event?.keyPressed ?? false)
    case .next:
      print("Next pressed")
      self.toggleLabel(self.nextLabel, enabled: event?.keyPressed ?? false)
    case .fastForward:
      print("Fast Forward pressed")
      self.toggleLabel(self.fastForwardLabel, enabled: event?.keyPressed ?? false)
    case .brightnessUp:
      print("Brightness up pressed")
    case .brightnessDown:
      print("Brightness down pressed")
    case .volumeUp:
      print("Volume up pressed")
    case .volumeDown:
      print("Volume down pressed")
    case .mute:
      print("Mute pressed")
    }
  }
}
