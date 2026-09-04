// mousemap: map extra mouse buttons, and keystrokes sent by a mouse's onboard
// profile, to macOS shortcuts. No kernel extension, no vendor software.
//
//   mousemap            run with ~/.config/mousemap.json
//   mousemap --learn    print what your mouse sends so you can write the config
//
// Config (~/.config/mousemap.json):
//   {
//     "device":  {"vendor": "0x1b1c", "product": "0x1b80"},
//     "keys":    {"1f": "back", "1e": "forward"},
//     "buttons": {"3": "back", "4": "forward"}
//   }
// "keys"    = HID keyboard usages (hex) from the mouse's keyboard interface.
// "buttons" = mouse button numbers (0 left, 1 right, 2 middle, 3+ extra).
import Cocoa
import IOKit.hid

let actions: [String: (CGKeyCode, CGEventFlags)] = [
    "back":           (33,  .maskCommand),   // cmd-[
    "forward":        (30,  .maskCommand),   // cmd-]
    "missionControl": (126, .maskControl),   // ctrl-up
    "appWindows":     (125, .maskControl),   // ctrl-down
    "spaceLeft":      (123, .maskControl),   // ctrl-left
    "spaceRight":     (124, .maskControl),   // ctrl-right
    "showDesktop":    (103, []),             // F11
]

let learn = CommandLine.arguments.contains("--learn")
let configPath = NSString("~/.config/mousemap.json").expandingTildeInPath
var buttonBindings: [Int64: (CGKeyCode, CGEventFlags)] = [:]
var usageBindings: [UInt32: (CGKeyCode, CGEventFlags)] = [:]
var deviceMatch: [String: Any] = [kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
                                  kIOHIDPrimaryUsageKey: kHIDUsage_GD_Keyboard]

func log(_ s: String) { fputs("mousemap: \(s)\n", stderr) }
func hex(_ s: String) -> Int? { Int(s.lowercased().replacingOccurrences(of: "0x", with: ""), radix: 16) }

func loadConfig() {
    buttonBindings = [:]; usageBindings = [:]
    guard let data = FileManager.default.contents(atPath: configPath),
          let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        log("no config at \(configPath)"); return
    }
    if let dev = obj["device"] as? [String: String] {
        if let v = dev["vendor"].flatMap(hex) { deviceMatch[kIOHIDVendorIDKey] = v }
        if let p = dev["product"].flatMap(hex) { deviceMatch[kIOHIDProductIDKey] = p }
    }
    for (k, a) in obj["keys"] as? [String: String] ?? [:] {
        guard let b = actions[a] else { log("unknown action \(a)"); continue }
        if let u = hex(k) { usageBindings[UInt32(u)] = b }
    }
    for (k, a) in obj["buttons"] as? [String: String] ?? [:] {
        guard let b = actions[a] else { log("unknown action \(a)"); continue }
        if let n = Int64(k) { buttonBindings[n] = b }
    }
    log("loaded \(buttonBindings.count) button + \(usageBindings.count) key bindings")
}

func sendKey(_ key: CGKeyCode, _ flags: CGEventFlags) {
    let src = CGEventSource(stateID: .hidSystemState)
    for down in [true, false] {
        guard let e = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: down) else { continue }
        e.flags = flags
        e.post(tap: .cghidEventTap)
    }
}

// Extra mouse buttons arrive as otherMouseDown/Up at a CGEvent tap.
var tap: CFMachPort?
let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
        return Unmanaged.passUnretained(event)
    }
    let button = event.getIntegerValueField(.mouseEventButtonNumber)
    if learn {
        if type == .otherMouseDown { print("button \(button)"); fflush(stdout) }
        return Unmanaged.passUnretained(event)
    }
    guard let (key, flags) = buttonBindings[button] else { return Unmanaged.passUnretained(event) }
    if type == .otherMouseDown { sendKey(key, flags) }
    return nil  // swallow down and up
}

// Keystrokes from the mouse's keyboard interface are read as raw HID reports.
// macOS refuses to seize keyboard-class devices (kIOReturnExclusiveAccess), and
// these keystrokes never reach the event system, so a plain open is enough.
let hid = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
IOHIDManagerRegisterInputValueCallback(hid, { _, _, _, value in
    let el = IOHIDValueGetElement(value)
    let page = IOHIDElementGetUsagePage(el), usage = IOHIDElementGetUsage(el)
    let pressed = IOHIDValueGetIntegerValue(value) != 0
    guard page == kHIDPage_KeyboardOrKeypad, usage >= 4, pressed else { return }
    if learn {
        let d = IOHIDElementGetDevice(el)
        let v = IOHIDDeviceGetProperty(d, kIOHIDVendorIDKey as CFString) as? Int ?? 0
        let p = IOHIDDeviceGetProperty(d, kIOHIDProductIDKey as CFString) as? Int ?? 0
        let name = IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "?"
        print("key \(String(usage, radix: 16))  device vendor=0x\(String(v, radix: 16)) product=0x\(String(p, radix: 16))  \(name)")
        fflush(stdout); return
    }
    if let (key, flags) = usageBindings[usage] { sendKey(key, flags) }
    else { log("unmapped key \(String(usage, radix: 16))") }
}, nil)
IOHIDManagerRegisterDeviceMatchingCallback(hid, { _, _, _, d in
    let name = IOHIDDeviceGetProperty(d, kIOHIDProductKey as CFString) as? String ?? "?"
    log("attached: \(name)")
}, nil)

if !learn { loadConfig() }
signal(SIGHUP) { _ in loadConfig() }

if !AXIsProcessTrusted() {
    AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
    log("needs Accessibility (System Settings > Privacy & Security > Accessibility)"); exit(1)
}
let mask = (1 << CGEventType.otherMouseDown.rawValue) | (1 << CGEventType.otherMouseUp.rawValue)
tap = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
                        eventsOfInterest: CGEventMask(mask), callback: tapCallback, userInfo: nil)
guard let tap else { log("could not create event tap"); exit(1) }
CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

IOHIDManagerSetDeviceMatching(hid, deviceMatch as CFDictionary)
IOHIDManagerScheduleWithRunLoop(hid, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
let r = IOHIDManagerOpen(hid, IOOptionBits(kIOHIDOptionsTypeNone))
if r != kIOReturnSuccess { log("IOHIDManagerOpen failed (\(r)); needs Input Monitoring (System Settings > Privacy & Security > Input Monitoring)"); exit(1) }
log("running\(learn ? " (learn mode: press buttons, ctrl-c to stop)" : "")")
CFRunLoopRun()
