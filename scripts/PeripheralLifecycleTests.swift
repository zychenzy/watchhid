import Foundation

var failed = 0
func check(_ cond: @autoclosure () -> Bool, _ msg: String) {
    if !cond() {
        fputs("FAIL: \(msg)\n", stderr)
        failed += 1
    }
}

typealias L = PeripheralLifecycle

func runForegroundOnlyTests() {
    var l = L()
    check(l.evaluate(at: 0) == .none && !l.running, "launch without a scene does not start")
    check(l.update(phase: .background, at: 1) == .none, "background launch does not advertise")
    check(l.update(phase: .inactive, at: 2) == .none, "inactive launch does not advertise")
    check(l.update(phase: .active, at: 3) == .start && l.running, "active starts")
    check(l.update(phase: .active, at: 4) == .none, "repeated active does not restart")
    check(l.update(phase: .background, at: 5) == .stop && !l.running, "background stops at once")
    check(l.evaluate(at: 100) == .none, "stopped stays stopped")
    check(l.update(phase: .active, at: 101) == .start, "return to active restarts")
}

func runInactiveGraceTests() {
    var l = L()
    _ = l.update(phase: .active, at: 0)
    check(l.update(phase: .inactive, at: 10) == .recheck(at: 10 + L.inactiveGrace), "inactive waits for grace")
    check(l.evaluate(at: 11) == .recheck(at: 10 + L.inactiveGrace), "grace measured from leaving")
    check(l.update(phase: .active, at: 12) == .none && l.running, "brief inactive keeps the session")
    check(l.evaluate(at: 20) == .none && l.running, "stale recheck after return does nothing")
    _ = l.update(phase: .inactive, at: 30)
    check(l.update(phase: .inactive, at: 31) == .recheck(at: 30 + L.inactiveGrace), "repeat inactive keeps first leave time")
    check(l.evaluate(at: 30 + L.inactiveGrace) == .stop && !l.running, "real inactive stops after grace")

    var b = L()
    _ = b.update(phase: .active, at: 0)
    _ = b.update(phase: .inactive, at: 1)
    check(b.update(phase: .background, at: 1.5) == .stop, "background during inactive grace stops at once")
}

func runTextEntryTests() {
    // Sheet makes the scene inactive; the send then completes and the scene returns.
    var l = L()
    _ = l.update(phase: .active, at: 0)
    check(l.textEntryBegan(at: 1) == .none, "sheet open while active")
    check(l.holdsForTextEntry(at: 2), "sheet holds")
    check(l.update(phase: .inactive, at: 2) == .recheck(at: 1 + L.textEntrySheetLimit), "sheet inactive does not stop")
    check(l.update(phase: .background, at: 3) == .recheck(at: 1 + L.textEntrySheetLimit), "sheet hold survives a background report")
    check(l.textEntryEnded(pendingSend: true, at: 10) == .recheck(at: 10 + L.pendingSendLimit), "pending send keeps session")
    check(l.running && l.holdsForTextEntry(at: 11), "send can proceed")
    check(l.update(phase: .active, at: 11) == .none, "returning active is a no-op")
    check(l.textSendSettled(at: 12) == .none && l.running, "send done while active keeps running")
    check(!l.holdsForTextEntry(at: 12), "hold released")

    // User actually leaves after dictating.
    var gone = L()
    _ = gone.update(phase: .active, at: 0)
    _ = gone.textEntryBegan(at: 1)
    _ = gone.update(phase: .background, at: 2)
    _ = gone.textEntryEnded(pendingSend: true, at: 5)
    check(gone.textSendSettled(at: 6) == .stop, "background after send stops")

    // Send never settles: bounded.
    var stuck = L()
    _ = stuck.update(phase: .active, at: 0)
    _ = stuck.textEntryBegan(at: 0)
    _ = stuck.update(phase: .background, at: 1)
    _ = stuck.textEntryEnded(pendingSend: true, at: 2)
    check(stuck.evaluate(at: 2 + L.pendingSendLimit - 0.1) == .recheck(at: 2 + L.pendingSendLimit), "before limit still held")
    check(stuck.evaluate(at: 2 + L.pendingSendLimit) == .stop, "pending send hold is bounded")

    // Sheet left open forever while backgrounded: bounded.
    var open = L()
    _ = open.update(phase: .active, at: 0)
    _ = open.textEntryBegan(at: 0)
    _ = open.update(phase: .background, at: 1)
    check(open.evaluate(at: L.textEntrySheetLimit) == .stop, "sheet hold is bounded")
    check(!open.textEntryOpen, "expired hold clears sheet state")

    // Cancelled sheet while the scene is still inactive: grace, not instant stop.
    var cancel = L()
    _ = cancel.update(phase: .active, at: 0)
    _ = cancel.textEntryBegan(at: 0)
    _ = cancel.update(phase: .inactive, at: 1)
    check(cancel.textEntryEnded(pendingSend: false, at: 50) == .recheck(at: 50 + L.inactiveGrace), "cancel waits for scene to return")
    check(cancel.update(phase: .active, at: 51) == .none && cancel.running, "scene returns, still running")

    // Settled without a hold is ignored; settled while the sheet is open is ignored.
    var idle = L()
    _ = idle.update(phase: .active, at: 0)
    check(idle.textSendSettled(at: 1) == .none, "no hold, no-op")
    _ = idle.textEntryBegan(at: 2)
    check(idle.textSendSettled(at: 3) == .none && idle.holdsForTextEntry(at: 3), "sheet still open keeps hold")
}

@main
struct PeripheralLifecycleTests {
    static func main() {
        runForegroundOnlyTests()
        runInactiveGraceTests()
        runTextEntryTests()
        if failed == 0 {
            print("All lifecycle tests passed")
        } else {
            fputs("\(failed) failures\n", stderr)
            exit(1)
        }
    }
}
