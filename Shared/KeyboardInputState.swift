import Foundation

/// Maps printable US-ASCII to boot-keyboard HID reports. No Bluetooth/UI.
/// Unsupported characters are skipped (counted), never remapped into wrong glyphs.
struct KeyboardInputState {
    static let reportID: UInt8 = 2
    static let interval: TimeInterval = 1.0 / 40.0

    private(set) var enabled = false
    private(set) var active = false
    private(set) var macReady = false
    private(set) var busy = false
    private(set) var skippedUnsupported = 0
    private(set) var queuedKeyCount = 0
    private var queue: [(mods: UInt8, key: UInt8)] = []
    private var phase: Phase = .idle
    private var lastStep = -Double.infinity
    private var current: (mods: UInt8, key: UInt8)?
    var usesReportID = true

    private enum Phase { case idle, down, up }

    mutating func availability(active: Bool, macReady: Bool) -> Data? {
        self.active = active
        self.macReady = macReady
        if active && macReady { return nil }
        return cancel()
    }

    mutating func arm() -> Bool {
        guard active && macReady else { return false }
        enabled = true
        return true
    }

    mutating func disarm() -> Data? {
        enabled = false
        return cancel()
    }

    /// Queue ASCII text. Returns false if refused (busy/disabled). Does not log plaintext.
    mutating func enqueueASCII(_ text: String) -> Bool {
        guard enabled && active && macReady && !busy else { return false }
        var items: [(UInt8, UInt8)] = []
        var skipped = 0
        for scalar in text.unicodeScalars {
            guard scalar.isASCII, let mapped = Self.mapASCII(UInt8(scalar.value)) else {
                skipped += 1
                continue
            }
            items.append(mapped)
        }
        guard !items.isEmpty else {
            skippedUnsupported += skipped
            return skipped == 0
        }
        queue.append(contentsOf: items.map { (mods: $0.0, key: $0.1) })
        queuedKeyCount = queue.count
        skippedUnsupported += skipped
        busy = true
        phase = .idle
        lastStep = -Double.infinity
        return true
    }

    mutating func cancel() -> Data? {
        queue.removeAll()
        queuedKeyCount = 0
        busy = false
        let release = current != nil ? encode(mods: 0, key: 0) : nil
        current = nil
        phase = .idle
        return release
    }

    /// Drain one HID step. Alternates key-down and key-up; rate-limited.
    mutating func step(at now: TimeInterval) -> Data? {
        guard enabled && active && macReady && busy && now.isFinite,
              now - lastStep >= Self.interval else { return nil }
        switch phase {
        case .idle, .up:
            guard let next = queue.first else {
                busy = false
                queuedKeyCount = 0
                current = nil
                phase = .idle
                return nil
            }
            queue.removeFirst()
            queuedKeyCount = queue.count
            current = next
            phase = .down
            lastStep = now
            return encode(mods: next.mods, key: next.key)
        case .down:
            phase = .up
            lastStep = now
            current = nil
            if queue.isEmpty {
                busy = false
                queuedKeyCount = 0
            }
            return encode(mods: 0, key: 0)
        }
    }

    private func encode(mods: UInt8, key: UInt8) -> Data {
        // Boot keyboard: modifier, reserved, 6 keycodes
        var bytes: [UInt8] = [mods, 0, key, 0, 0, 0, 0, 0]
        if usesReportID {
            bytes.insert(Self.reportID, at: 0)
        }
        return Data(bytes)
    }

    /// US keyboard usage mapping for printable ASCII. Returns (modifier, keycode).
    static func mapASCII(_ c: UInt8) -> (UInt8, UInt8)? {
        let shift: UInt8 = 0x02
        switch c {
        case 0x09: return (0, 0x2B) // Tab
        case 0x0A, 0x0D: return (0, 0x28) // Enter
        case 0x20: return (0, 0x2C) // Space
        case 0x27: return (0, 0x34) // '
        case 0x2C: return (0, 0x36) // ,
        case 0x2D: return (0, 0x2D) // -
        case 0x2E: return (0, 0x37) // .
        case 0x2F: return (0, 0x38) // /
        case 0x30: return (0, 0x27) // 0
        case 0x31...0x39: return (0, c - 0x31 + 0x1E) // 1-9
        case 0x3B: return (0, 0x33) // ;
        case 0x3D: return (0, 0x2E) // =
        case 0x5B: return (0, 0x2F) // [
        case 0x5C: return (0, 0x31) // \
        case 0x5D: return (0, 0x30) // ]
        case 0x60: return (0, 0x35) // `
        case 0x61...0x7A: return (0, c - 0x61 + 0x04) // a-z
        case 0x41...0x5A: return (shift, c - 0x41 + 0x04) // A-Z
        case 0x21: return (shift, 0x1E) // !
        case 0x40: return (shift, 0x1F) // @
        case 0x23: return (shift, 0x20) // #
        case 0x24: return (shift, 0x21) // $
        case 0x25: return (shift, 0x22) // %
        case 0x5E: return (shift, 0x23) // ^
        case 0x26: return (shift, 0x24) // &
        case 0x2A: return (shift, 0x25) // *
        case 0x28: return (shift, 0x26) // (
        case 0x29: return (shift, 0x27) // )
        case 0x5F: return (shift, 0x2D) // _
        case 0x2B: return (shift, 0x2E) // +
        case 0x7B: return (shift, 0x2F) // {
        case 0x7C: return (shift, 0x31) // |
        case 0x7D: return (shift, 0x30) // }
        case 0x3A: return (shift, 0x33) // :
        case 0x22: return (shift, 0x34) // "
        case 0x3C: return (shift, 0x36) // <
        case 0x3E: return (shift, 0x37) // >
        case 0x3F: return (shift, 0x38) // ?
        case 0x7E: return (shift, 0x35) // ~
        default: return nil
        }
    }
}
