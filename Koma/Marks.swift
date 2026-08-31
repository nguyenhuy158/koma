import Foundation

/// Marks keyed by Photos local identifier, stored as one JSON blob in UserDefaults.
/// ponytail: swap for SwiftData when marks need notes, tags, or to outlive a reinstall.
///
/// Pure functions on purpose — the view holds the state, this holds the rules.
enum MarkStore {
    static func decode(_ json: String) -> [String: [Double]] {
        (try? JSONDecoder().decode([String: [Double]].self, from: Data(json.utf8))) ?? [:]
    }

    static func encode(_ all: [String: [Double]]) -> String {
        guard let d = try? JSONEncoder().encode(all) else { return "{}" }
        return String(decoding: d, as: UTF8.self)
    }

    static func marks(for clip: String, in json: String) -> [Double] {
        decode(json)[clip] ?? []
    }

    /// Returns the store with `marks` saved under `clip`. An empty clip id is dropped:
    /// keying every unidentified video under "" would pool their marks together.
    static func setting(_ marks: [Double], for clip: String, in json: String) -> String {
        guard !clip.isEmpty else { return json }
        var all = decode(json)
        all[clip] = marks
        return encode(all)
    }

    /// A tap lands within a frame or so of the mark, never exactly on it.
    static func index(near t: Double, in marks: [Double], fps: Double) -> Int? {
        let tol = 1.5 / max(fps, 1)
        return marks.firstIndex { abs($0 - t) < tol }
    }

    static func toggle(_ marks: [Double], at t: Double, fps: Double) -> [Double] {
        var out = marks
        if let i = index(near: t, in: out, fps: fps) { out.remove(at: i) }
        else { out.append(t); out.sort() }
        return out
    }

    /// Next point of interest in `dir`. Half a frame of slack, or landing on a mark
    /// would immediately re-find that same mark.
    static func next(after t: Double, in pois: [Double], dir: Int, fps: Double) -> Double? {
        let eps = 0.5 / max(fps, 1)
        let sorted = pois.sorted()
        return dir > 0 ? sorted.first { $0 > t + eps } : sorted.last { $0 < t - eps }
    }
}
