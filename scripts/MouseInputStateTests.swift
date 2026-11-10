import Foundation

var failed = 0
func check(_ cond: @autoclosure () -> Bool, _ msg: String) {
    if !cond() {
        fputs("FAIL: \(msg)\n", stderr)
        failed += 1
    }
}

func runMouseTests() {
    var mouse = MouseInputState()
    check(!mouse.enabled && mouse.frame(at: 0) == nil && mouse.pressClick() == nil, "default no output")
    check(!mouse.arm(), "cannot arm without availability")
    check(mouse.availability(active: true, macReady: true) == nil, "availability never moves")
    check(mouse.arm(), "explicit arm")
    mouse.beginTouch(x: 0, y: 0, at: 0)
    check(mouse.frame(at: 0) == nil, "touch down alone never moves")
    mouse.moveTouch(x: 0.3, y: -0.3)
    check(mouse.frame(at: 0) == nil, "subpixel stays pending")
    // Baseline: small-but-quantized motion emits WITHOUT requiring drag classification
    mouse.moveTouch(x: 2, y: -2)
    check(mouse.frame(at: 0) != nil, "baseline emits before drag threshold")
    // Exceed drag threshold for classification
    mouse.moveTouch(x: 12, y: -12)
    check(mouse.dragged, "drag engaged")
    check(mouse.frame(at: 0.05) != nil, "drag continues")
    check(mouse.pressClick() == nil, "cannot click during drag")
    let endDrag = mouse.endTouch(at: 1)
    check(endDrag.outcome == .none, "drag end is not click")
    check(mouse.frame(at: 2) == nil, "lifting drops backlog immediately")

    // Tap → left click outcome
    mouse.beginTouch(x: 0, y: 0, at: 10)
    let tap = mouse.endTouch(at: 10.1)
    check(tap.outcome == .leftClick, "short tap is left click")
    check(mouse.pressClick() == Data([1, 0, 0, 0]), "explicit click down")
    check(mouse.pressClick() == nil, "no duplicate down")
    check(mouse.releaseClick() == Data([0, 0, 0, 0]), "click up")
    check(mouse.releaseClick() == nil, "no unsolicited neutral output")
    _ = mouse.pressClick()
    check(mouse.availability(active: false, macReady: true) == Data([0, 0, 0, 0]), "inactive releases held click")

    // Long press → right
    check(mouse.availability(active: true, macReady: true) == nil, "reactivate")
    check(mouse.arm(), "rearm")
    mouse.beginTouch(x: 1, y: 1, at: 20)
    check(mouse.pollLongPress(at: 20.2) == nil, "before long press")
    let right = mouse.pollLongPress(at: 20.6)
    check(right == Data([2, 0, 0, 0]), "long press right down")
    let endRight = mouse.endTouch(at: 20.7)
    check(endRight.outcome == .rightClick, "long press outcome")
    check(endRight.release == Data([0, 0, 0, 0]), "long press release")

    // Report ID prefix
    mouse.usesReportID = true
    check(mouse.availability(active: true, macReady: true) == nil, "id mode ready")
    check(mouse.arm(), "id arm")
    check(mouse.pressClick() == Data([1, 1, 0, 0, 0]), "report id prefixed left")
    _ = mouse.releaseClick()
}

func runKeyboardTests() {
    var kb = KeyboardInputState()
    check(KeyboardInputState.mapASCII(0x61)?.1 == 0x04, "a keycode")
    check(KeyboardInputState.mapASCII(0x41)?.0 == 0x02, "A shift")
    check(KeyboardInputState.mapASCII(0x20)?.1 == 0x2C, "space")
    check(KeyboardInputState.mapASCII(0x21)?.1 == 0x1E, "bang")
    check(KeyboardInputState.mapASCII(0xE4) == nil, "non-ascii rejected")
    check(!kb.enqueueASCII("hi"), "cannot enqueue before arm")
    check(kb.availability(active: true, macReady: true) == nil, "kb avail")
    check(kb.arm(), "kb arm")
    check(kb.enqueueASCII("A!你"), "enqueue mixed")
    check(kb.skippedUnsupported >= 1, "skipped non-ascii")
    let down = kb.step(at: 0)
    check(down == Data([2, 0x02, 0, 0x04, 0, 0, 0, 0, 0]), "A down with report id")
    let up = kb.step(at: 0.05)
    check(up == Data([2, 0, 0, 0, 0, 0, 0, 0, 0]), "key up")
    _ = kb.step(at: 0.1)
    _ = kb.step(at: 0.15)
    check(kb.cancel() == nil, "cancel after complete key-up emits no unsolicited release")
}

func runLifecycleAndMetadataTests() {
    for keyboard in [false, true] {
        let map = HIDMetadata.value(for: "2A4B", keyboardEnabled: keyboard)
        check(map == Data(keyboard ? HIDDescriptors.mouseKeyboardReportMap : HIDDescriptors.mouseReportMap), "cached map matches report mode")
        check(HIDMetadata.value(for: "2A4A") == Data([0x11, 0x01, 0, 2]), "cached HID Information")
        for uuid in ["2A29", "2A24", "2A50"] {
            check(HIDMetadata.value(for: uuid)?.isEmpty == false, "immutable metadata remains readable without callback: \(uuid)")
        }
        for uuid in ["2A4D", "2A19", "2A4E", "2A4C"] {
            check(HIDMetadata.value(for: uuid) == nil, "mutable attribute stays dynamic: \(uuid)")
        }
    }
    var m = MouseInputState()
    _ = m.availability(active: true, macReady: true); _ = m.arm()
    m.beginTouch(x: 0, y: 0, at: 0)
    check(m.pollLongPress(at: 0.6) == Data([2,0,0,0]), "held right before overlay")
    check(m.availability(active: false, macReady: true) == Data([0,0,0,0]), "overlay/inactive releases right")
    check(m.endTouch(at: 0.8).outcome == .none, "inactive lift cannot click")
    _ = m.availability(active: true, macReady: true); _ = m.arm()
    check(m.frame(at: 1) == nil, "return cannot replay prior gesture")
    m.beginTouch(x: 0, y: 0, at: 1); m.moveTouch(x: 20, y: 0)
    _ = m.availability(active: true, macReady: false)
    check(m.frame(at: 2) == nil && !m.enabled, "subscription loss disarms and drops movement")
    _ = m.availability(active: true, macReady: true); _ = m.arm()
    check(m.frame(at: 3) == nil, "resubscribe requires fresh touch")
}

runMouseTests()
runKeyboardTests()
runLifecycleAndMetadataTests()
if failed == 0 {
    print("All logic tests passed")
} else {
    fputs("\(failed) failures\n", stderr)
    exit(1)
}
