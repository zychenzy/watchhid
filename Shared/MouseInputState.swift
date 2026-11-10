import Foundation

/// Pure relative HID mouse + touchpad gesture state. No Bluetooth, timers, UI or system input.
/// Movement semantics match a3c9eaf baseline (emit relative frames while touching).
/// Tap / long-press classification is layered on top without blocking move reports.
struct MouseInputState {
    static let interval: TimeInterval = 1.0 / 30.0
    static let dragThreshold: Double = 6.0
    static let longPress: TimeInterval = 0.55
    /// Crown units to HID wheel ticks. Positive crown delta scrolls down.
    static let wheelScale: Double = 3.0
    static let wheelBacklog: Double = 254

    enum GestureOutcome: Equatable {
        case none
        case leftClick
        case rightClick
    }

    private(set) var enabled = false
    private(set) var active = false
    private(set) var macReady = false
    private(set) var touching = false
    private(set) var dragged = false
    private(set) var buttonDown = false
    private(set) var buttons: UInt8 = 0
    private var lastX = 0.0
    private var lastY = 0.0
    private var startX = 0.0
    private var startY = 0.0
    private var touchBeganAt = 0.0
    private var pendingX = 0.0
    private var pendingY = 0.0
    private var pendingWheel = 0.0
    private var lastFrame = -Double.infinity
    private var longPressFired = false
    /// When true, encoded mouse reports are prefixed with Report ID 1 (composite map).
    var usesReportID = false

    var hasPendingWheel: Bool { abs(pendingWheel) >= 1 }

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
        endTouchQuiet()
        pendingWheel = 0
        return releaseButtons()
    }

    mutating func beginTouch(x: Double, y: Double, at now: TimeInterval) {
        guard enabled && active && macReady && !buttonDown && x.isFinite && y.isFinite && now.isFinite else { return }
        touching = true
        dragged = false
        longPressFired = false
        startX = x; startY = y
        lastX = x; lastY = y
        touchBeganAt = now
        pendingX = 0; pendingY = 0
        lastFrame = -Double.infinity
    }

    mutating func beginTouch(x: Double, y: Double) {
        beginTouch(x: x, y: y, at: ProcessInfo.processInfo.systemUptime)
    }

    mutating func moveTouch(x: Double, y: Double) {
        guard touching && enabled && active && macReady && x.isFinite && y.isFinite else { return }
        let dx = x - startX
        let dy = y - startY
        if !dragged && (dx * dx + dy * dy) >= (Self.dragThreshold * Self.dragThreshold) {
            dragged = true
        }
        // Bounded backlog: never replay a long gesture after congestion. (baseline)
        pendingX = max(-254, min(254, pendingX + (x - lastX) * 1.8))
        pendingY = max(-254, min(254, pendingY + (y - lastY) * 1.8))
        lastX = x; lastY = y
    }

    /// While finger is still down, emit right-button down once after long-press without drag.
    mutating func pollLongPress(at now: TimeInterval) -> Data? {
        guard touching && enabled && active && macReady && !dragged && !longPressFired && !buttonDown,
              now.isFinite, now - touchBeganAt >= Self.longPress else { return nil }
        longPressFired = true
        buttons = 0x02
        buttonDown = true
        return encode(buttons: buttons, x: 0, y: 0)
    }

    /// Accumulate Digital Crown rotation into the existing baseline wheel byte.
    /// Positive `delta` (increasing digitalCrownRotation / event.offset) is
    /// treated as scroll-down, matching typical Watch list motion, and is
    /// stored as a negative HID wheel value.
    mutating func addCrownDelta(_ delta: Double) {
        guard enabled && active && macReady && delta.isFinite, delta != 0 else { return }
        pendingWheel = max(-Self.wheelBacklog, min(Self.wheelBacklog, pendingWheel + (-delta * Self.wheelScale)))
    }

    /// Baseline movement: emit while touching whenever pending deltas exist (does NOT require dragged).
    /// Wheel may emit without a touch, still on the same 4-byte report.
    mutating func frame(at now: TimeInterval) -> Data? {
        guard enabled && active && macReady && now.isFinite,
              now - lastFrame >= Self.interval else { return nil }
        let x = touching ? max(-127, min(127, Int(pendingX))) : 0
        let y = touching ? max(-127, min(127, Int(pendingY))) : 0
        let wheel = max(-127, min(127, Int(pendingWheel)))
        guard x != 0 || y != 0 || wheel != 0 else { return nil }
        if touching {
            pendingX -= Double(x)
            pendingY -= Double(y)
        }
        pendingWheel -= Double(wheel)
        lastFrame = now
        return encode(buttons: buttons, x: x, y: y, wheel: wheel)
    }

    mutating func endTouch(at now: TimeInterval) -> (moveFlush: Data?, outcome: GestureOutcome, release: Data?) {
        defer { endTouchQuiet() }
        guard touching else { return (nil, .none, nil) }
        if longPressFired {
            let up = releaseButtons()
            return (nil, .rightClick, up)
        }
        if dragged {
            return (nil, .none, nil)
        }
        let dwell = now.isFinite ? (now - touchBeganAt) : 0
        if dwell < Self.longPress {
            return (nil, .leftClick, nil)
        }
        return (nil, .none, nil)
    }

    mutating func endTouch() {
        _ = endTouch(at: ProcessInfo.processInfo.systemUptime)
    }

    private mutating func endTouchQuiet() {
        touching = false
        dragged = false
        pendingX = 0; pendingY = 0
        // Wheel is independent of a finger lift; only availability/disarm drops it.
    }

    mutating func pressClick(buttonMask: UInt8 = 0x01) -> Data? {
        guard enabled && active && macReady && !touching && !buttonDown else { return nil }
        buttonDown = true
        buttons = buttonMask
        return encode(buttons: buttons, x: 0, y: 0)
    }

    mutating func releaseButtons() -> Data? {
        guard buttonDown else { return nil }
        buttonDown = false
        buttons = 0
        return encode(buttons: 0, x: 0, y: 0)
    }

    mutating func releaseClick() -> Data? { releaseButtons() }

    private func encode(buttons: UInt8, x: Int, y: Int, wheel: Int = 0) -> Data {
        var bytes: [UInt8] = [buttons, UInt8(bitPattern: Int8(x)), UInt8(bitPattern: Int8(y)), UInt8(bitPattern: Int8(wheel))]
        if usesReportID {
            bytes.insert(1, at: 0)
        }
        return Data(bytes)
    }
}
