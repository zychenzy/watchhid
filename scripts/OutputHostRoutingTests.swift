import Foundation

var failed = 0
func check(_ cond: @autoclosure () -> Bool, _ msg: String) {
    if !cond() {
        fputs("FAIL: \(msg)\n", stderr)
        failed += 1
    }
}

func runOutputHostRoutingTests() {
    let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    let c = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!

    check(OutputHostRouting.resolveTarget(selectedID: nil, availableIDs: []) == nil, "no hosts")
    check(OutputHostRouting.resolveTarget(selectedID: nil, availableIDs: [a]) == a, "single host, no selection")
    check(OutputHostRouting.resolveTarget(selectedID: nil, availableIDs: [a, b]) == nil, "two hosts, no selection, do not guess")
    check(OutputHostRouting.resolveTarget(selectedID: b, availableIDs: [a, b]) == b, "persisted selection wins")
    check(OutputHostRouting.resolveTarget(selectedID: b, availableIDs: [a]) == a, "selected away, only one left, temporary fallback")
    check(OutputHostRouting.resolveTarget(selectedID: c, availableIDs: [a, b]) == nil, "selected away, two remain, require a pick")
    check(OutputHostRouting.resolveTarget(selectedID: a, availableIDs: [b, a]) == a, "selected still used after another host appears")

    check(!OutputHostRouting.savedHostIsAway(selectedID: nil, availableIDs: [a, b]), "no saved host")
    check(!OutputHostRouting.savedHostIsAway(selectedID: a, availableIDs: [a, b]), "saved host present")
    check(OutputHostRouting.savedHostIsAway(selectedID: c, availableIDs: [a, b]), "saved host away")

    let first = OutputHostRouting.assignOrdinals(existing: [:], ids: [b, a])
    check(first[a] == 1 && first[b] == 2, "first assignment is stable by UUID order, not OS")
    let kept = OutputHostRouting.assignOrdinals(existing: first, ids: [b])
    check(kept[a] == 1 && kept[b] == 2, "disconnected host keeps its number")
    let added = OutputHostRouting.assignOrdinals(existing: kept, ids: [b, c])
    check(added[a] == 1 && added[b] == 2 && added[c] == 3, "new host gets the next number, not a reused 1")
    let returned = OutputHostRouting.assignOrdinals(existing: added, ids: [a, b, c])
    check(returned[a] == 1 && returned[b] == 2 && returned[c] == 3, "returning host keeps Device 1")
}

@main
enum OutputHostRoutingTestMain {
    static func main() {
        runOutputHostRoutingTests()
        if failed == 0 {
            print("All output-host routing tests passed")
        } else {
            fputs("\(failed) failures\n", stderr)
            exit(1)
        }
    }
}
