import Foundation

/// Pure relative HID state machine. No Bluetooth, timers, UI or system input.
struct MouseInputState {
    static let interval: TimeInterval = 1.0 / 30.0
    private(set) var enabled = false
    private(set) var active = false
    private(set) var macReady = false
    private(set) var touching = false
    private(set) var buttonDown = false
    private var lastX = 0.0
    private var lastY = 0.0
    private var pendingX = 0.0
    private var pendingY = 0.0
    private var lastFrame = -Double.infinity

    mutating func availability(active: Bool, macReady: Bool) -> Data? {
        self.active = active
        self.macReady = macReady
        return active && macReady ? nil : disarm()
    }
    mutating func arm() -> Bool {
        guard active && macReady else { return false }
        enabled = true
        return true
    }
    mutating func disarm() -> Data? {
        enabled = false
        endTouch()
        return releaseClick()
    }
    mutating func beginTouch(x: Double, y: Double) {
        guard enabled && active && macReady && !buttonDown && x.isFinite && y.isFinite else { return }
        touching = true
        lastX = x; lastY = y
        pendingX = 0; pendingY = 0
        lastFrame = -Double.infinity
    }
    mutating func moveTouch(x: Double, y: Double) {
        guard touching && enabled && active && macReady && x.isFinite && y.isFinite else { return }
        // Bounded backlog: never replay a long gesture after congestion.
        pendingX = max(-254, min(254, pendingX + (x - lastX) * 1.8))
        pendingY = max(-254, min(254, pendingY + (y - lastY) * 1.8))
        lastX = x; lastY = y
    }
    mutating func frame(at now: TimeInterval) -> Data? {
        guard touching && enabled && active && macReady && now.isFinite,
              now - lastFrame >= Self.interval else { return nil }
        let x = max(-127, min(127, Int(pendingX)))
        let y = max(-127, min(127, Int(pendingY)))
        guard x != 0 || y != 0 else { return nil }
        pendingX -= Double(x); pendingY -= Double(y)
        lastFrame = now
        return Data([0, UInt8(bitPattern: Int8(x)), UInt8(bitPattern: Int8(y)), 0])
    }
    mutating func endTouch() {
        touching = false
        pendingX = 0; pendingY = 0
    }
    mutating func pressClick() -> Data? {
        guard enabled && active && macReady && !touching && !buttonDown else { return nil }
        buttonDown = true
        return Data([1, 0, 0, 0])
    }
    mutating func releaseClick() -> Data? {
        guard buttonDown else { return nil }
        buttonDown = false
        return Data([0, 0, 0, 0])
    }
}
