# mousemap

Map the extra buttons on a gaming mouse to macOS shortcuts. One Swift file, no kernel extension, no vendor software, nothing to buy.

Built because a Corsair Dark Core RGB Pro carrying a stale iCUE onboard profile sends its side buttons as keyboard keys ("1" and "2") on a hidden keyboard interface. macOS drops those keystrokes and refuses to let user-space seize a keyboard-class device, so SensibleSideButtons, Mac Mouse Fix and friends never see them. mousemap reads the raw HID report instead and posts the shortcut you want.

It also handles ordinary extra buttons (4, 5, and up) through a CGEvent tap, so it covers mice that behave normally too.

## Install

```
git clone https://github.com/mpiv-ai/mousemap
cd mousemap
make install
```

`make install` builds the binary, wraps it in `~/Applications/MouseMap.app`, writes a LaunchAgent so it starts at login, and copies `mousemap.example.json` to `~/.config/mousemap.json` if you have no config yet. Allow the two permission prompts (Accessibility, then Input Monitoring). Watch it work with:

```
tail -f ~/Library/Logs/mousemap.log
```

Requires Xcode command line tools (`xcode-select --install`).

## Configure

`~/.config/mousemap.json`:

```json
{
  "device":  {"vendor": "0x1b1c", "product": "0x1b80"},
  "keys":    {"1f": "back", "1e": "forward"},
  "buttons": {"3": "back", "4": "forward"}
}
```

- `device`: USB vendor and product ID of the mouse whose keyboard interface to read. Omit to listen to every keyboard-class device.
- `keys`: HID keyboard usage (hex) to action, for mice that send keystrokes.
- `buttons`: mouse button number to action. 0 is left, 1 right, 2 middle, 3 and up are the extras.

Actions: `back`, `forward`, `missionControl`, `appWindows`, `spaceLeft`, `spaceRight`, `showDesktop`. Back and forward post Cmd-[ and Cmd-], which every browser and Finder honour.

After editing the config run `make reload` (sends SIGHUP). No rebuild needed.

## Find out what your mouse sends

```
make learn
```

Press each button. Real mouse buttons print as `button N`. Keystrokes from an onboard profile print with the device's vendor and product ID, ready to paste into the config.

## Rebuilding

The bundle is ad-hoc signed, so every build has a new code hash and macOS forgets the permission grants. `make install` resets them with `tccutil` and you allow the prompts again. Config changes never need a rebuild.

## Uninstall

```
make uninstall
```

## Notes

- Tested on macOS 26 (Tahoe), Apple Silicon.
- `IOHIDManagerOpen` must be called once per manager. Trying a seize first and falling back to a plain open leaves the manager half-attached and no reports arrive.
- License: MIT.
