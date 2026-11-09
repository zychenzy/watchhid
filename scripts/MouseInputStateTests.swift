import Foundation
@main struct MouseInputStateTests {
    static func main() {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            precondition(condition, message); checks += 1
        }
        var mouse = MouseInputState()
        check(!mouse.enabled && mouse.frame(at: 0) == nil && mouse.pressClick() == nil, "default no output")
        check(!mouse.arm(), "cannot arm without availability")
        check(mouse.availability(active: true, macReady: true) == nil, "availability never moves")
        check(mouse.arm(), "explicit arm")
        mouse.beginTouch(x: 0, y: 0)
        check(mouse.frame(at: 0) == nil, "touch down alone never moves")
        mouse.moveTouch(x: 0.3, y: -0.3)
        check(mouse.frame(at: 0) == nil, "subpixel accumulates")
        mouse.moveTouch(x: 0.6, y: -0.6)
        check(mouse.frame(at: 0) == Data([0, 1, 255, 0]), "signed 4 byte encoding")
        mouse.moveTouch(x: 1.2, y: -1.2)
        check(mouse.frame(at: 0.01) == nil, "30Hz rate limit")
        check(mouse.frame(at: 0.04) == Data([0, 1, 255, 0]), "fractional remainder retained")
        mouse.moveTouch(x: 10000, y: -10000)
        check(mouse.frame(at: 0.08) == Data([0, 127, 129, 0]), "signed range clamp")
        check(mouse.pressClick() == nil, "cannot click during drag")
        mouse.endTouch()
        check(mouse.frame(at: 1) == nil, "lifting drops backlog immediately")
        check(mouse.pressClick() == Data([1, 0, 0, 0]), "explicit click down")
        check(mouse.pressClick() == nil, "no duplicate down")
        check(mouse.releaseClick() == Data([0, 0, 0, 0]), "click up")
        check(mouse.releaseClick() == nil, "no unsolicited neutral output")
        _ = mouse.pressClick()
        check(mouse.availability(active: false, macReady: true) == Data([0, 0, 0, 0]), "inactive releases held click")
        check(!mouse.enabled && !mouse.touching && !mouse.buttonDown, "inactive resets state")
        check(mouse.frame(at: 2) == nil && mouse.pressClick() == nil, "inactive cannot send")
        _ = mouse.availability(active: true, macReady: true)
        check(!mouse.enabled, "return foreground does not auto enable")
        _ = mouse.arm(); mouse.beginTouch(x: 0, y: 0); mouse.moveTouch(x: 20, y: 20)
        _ = mouse.availability(active: true, macReady: false)
        check(!mouse.enabled && mouse.frame(at: 3) == nil, "unsubscribe discards pending movement")
        _ = mouse.availability(active: true, macReady: true); _ = mouse.arm()
        mouse.beginTouch(x: .nan, y: 0)
        check(!mouse.touching, "invalid coordinates ignored")
        mouse.beginTouch(x: 0, y: 0); mouse.moveTouch(x: .infinity, y: 0)
        check(mouse.frame(at: 4) == nil, "nonfinite movement ignored")
        _ = mouse.disarm()
        check(mouse.frame(at: 10) == nil && !mouse.enabled, "explicit disable stops")
        print("PASS \(checks) pure HID state/encoding/deadman tests; no Bluetooth/system input")
    }
}
