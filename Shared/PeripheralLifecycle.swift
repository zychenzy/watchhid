import Foundation

/// Decides when the BLE HID peripheral should exist. Pure state: no Bluetooth,
/// timers, or UI. PeripheralProbe applies each Decision and schedules rechecks.
///
/// Rules:
/// - The peripheral runs only while the scene is active (foreground).
/// - Background stops it at once; inactive stops it after a short grace, so a
///   brief overlay does not churn the connection.
/// - The system text-input (dictation) sheet and the send that follows it hold
///   the session for a bounded time, then the normal rules apply again.
struct PeripheralLifecycle {
    enum Phase: Equatable {
        case active
        case inactive
        case background
    }

    enum Decision: Equatable {
        case none
        case start
        case stop
        /// Evaluate again at this uptime; the peripheral is still running.
        case recheck(at: TimeInterval)
    }

    static let inactiveGrace: TimeInterval = 3
    static let textEntrySheetLimit: TimeInterval = 120
    static let pendingSendLimit: TimeInterval = 45

    private(set) var phase: Phase = .background
    private(set) var running = false
    private(set) var textEntryOpen = false
    private var holdUntil: TimeInterval?
    private var leftAt: TimeInterval?

    /// True while the dictation sheet or its pending send keeps the session alive.
    func holdsForTextEntry(at now: TimeInterval) -> Bool {
        guard let holdUntil else { return false }
        return now < holdUntil
    }

    mutating func update(phase newPhase: Phase, at now: TimeInterval) -> Decision {
        if newPhase == .active {
            leftAt = nil
        } else if phase == .active || leftAt == nil {
            leftAt = now
        }
        phase = newPhase
        return evaluate(at: now)
    }

    mutating func textEntryBegan(at now: TimeInterval) -> Decision {
        textEntryOpen = true
        holdUntil = now + Self.textEntrySheetLimit
        return evaluate(at: now)
    }

    /// The sheet returned. With text, hold while it is sent; without, fall back
    /// to the inactive grace in case the scene is still returning to active.
    mutating func textEntryEnded(pendingSend: Bool, at now: TimeInterval) -> Decision {
        textEntryOpen = false
        if pendingSend {
            holdUntil = now + Self.pendingSendLimit
        } else {
            holdUntil = nil
            if phase != .active { leftAt = now }
        }
        return evaluate(at: now)
    }

    /// The dictated text was typed, skipped, cancelled, or abandoned.
    mutating func textSendSettled(at now: TimeInterval) -> Decision {
        guard !textEntryOpen, holdUntil != nil else { return .none }
        holdUntil = nil
        if phase != .active { leftAt = now }
        return evaluate(at: now)
    }

    mutating func evaluate(at now: TimeInterval) -> Decision {
        if phase == .active {
            leftAt = nil
            guard !running else { return .none }
            running = true
            return .start
        }
        guard running else { return .none }
        if let holdUntil {
            if now < holdUntil { return .recheck(at: holdUntil) }
            self.holdUntil = nil
            textEntryOpen = false
        }
        if phase == .inactive {
            let since = leftAt ?? now
            let deadline = since + Self.inactiveGrace
            if now < deadline { return .recheck(at: deadline) }
        }
        running = false
        return .stop
    }
}
