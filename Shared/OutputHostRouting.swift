import Foundation

/// Neutral, testable rules for choosing which subscribed HID host
/// receives reports. This type does not guess Mac versus iPhone.
enum OutputHostRouting {
    /// Pick exactly one host.
    ///
    /// If the persisted selection is currently available, use it.
    /// If that host is missing, or no selection has been saved, and exactly
    /// one host is available, use that host temporarily without treating it
    /// as a newly persisted choice.
    /// If two or more hosts are available and the selection is missing or
    /// unset, return nil so the user can pick one. Do not guess the OS.
    static func resolveTarget(selectedID: UUID?, availableIDs: [UUID]) -> UUID? {
        let available = unique(availableIDs)
        if let selectedID, available.contains(selectedID) {
            return selectedID
        }
        if available.count == 1 {
            return available[0]
        }
        return nil
    }

    /// True when a persisted selection exists but is not in the current set.
    static func savedHostIsAway(selectedID: UUID?, availableIDs: [UUID]) -> Bool {
        guard let selectedID else { return false }
        return !unique(availableIDs).contains(selectedID)
    }

    /// Assign stable Device N ordinals. New hosts get the next unused
    /// positive integer. Existing mappings are kept after disconnect so a
    /// returning host keeps the same number.
    static func assignOrdinals(existing: [UUID: Int], ids: [UUID]) -> [UUID: Int] {
        var map: [UUID: Int] = [:]
        var used = Set<Int>()
        for (id, value) in existing where value > 0 {
            if map[id] == nil {
                map[id] = value
                used.insert(value)
            }
        }
        for id in unique(ids).sorted(by: { $0.uuidString < $1.uuidString }) {
            if map[id] == nil {
                var n = 1
                while used.contains(n) { n += 1 }
                map[id] = n
                used.insert(n)
            }
        }
        return map
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        var out: [UUID] = []
        for id in ids where !seen.contains(id) {
            seen.insert(id)
            out.append(id)
        }
        return out
    }
}
