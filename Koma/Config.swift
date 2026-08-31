import Foundation

// One table, one place. A default written out in both ContentView and SettingsView is
// how two screens end up disagreeing about the same UserDefaults key.

/// A tunable value: its storage key, default, and the bounds the settings slider uses.
struct Knob {
    let key: String
    let def: Double
    let range: ClosedRange<Double>
    let step: Double
}

enum Knobs {
    static let ptsPerFrame = Knob(key: "ptsPerFrame", def: 10,  range: 4...40,    step: 1)
    static let holdRate    = Knob(key: "holdRate",    def: 20,  range: 5...60,    step: 5)
    static let smallSeek   = Knob(key: "smallSeek",   def: 1,   range: 0.1...5,   step: 0.1)
    static let bigSeek     = Knob(key: "bigSeek",     def: 60,  range: 5...300,   step: 5)
    static let hugeSeek    = Knob(key: "hugeSeek",    def: 300, range: 60...1800, step: 30)
    static let onionCount  = Knob(key: "onionCount",  def: 3,   range: 1...6,     step: 1)
    static let hitSense    = Knob(key: "hitSense",    def: 2.5, range: 1.5...6,   step: 0.1)
    static let volume      = Knob(key: "volume",      def: 1,   range: 0...1,     step: 0.05)

    static let all = [ptsPerFrame, holdRate, smallSeek, bigSeek, hugeSeek, onionCount, hitSense, volume]

    // Toggles carry no range, so they stay plain pairs.
    static let haptics   = (key: "haptics",   def: true)
    static let keepAwake = (key: "keepAwake", def: true)
    // Marks are user data, not a setting — reset must never touch this one.
    static let marksStore = (key: "marksStore", def: "{}")

    /// Writes through UserDefaults so it can't silently miss a knob the way a
    /// hand-listed block of assignments does.
    static func reset(_ d: UserDefaults = .standard) {
        for k in all { d.set(k.def, forKey: k.key) }
        d.set(haptics.def, forKey: haptics.key)
        d.set(keepAwake.def, forKey: keepAwake.key)
    }
}

/// Every number the user reads. Kept together so a skip button and its settings row
/// can never describe the same value differently.
enum Fmt {
    /// Position readout: `01:07.694`.
    static func timecode(_ s: Double) -> String {
        // Round, don't truncate — binary doubles make 876.31 land at .30999 and read as .309.
        let ms = Int((max(0, s) * 1000).rounded())
        return String(format: "%02d:%02d.%03d", ms / 60_000, (ms / 1000) % 60, ms % 1000)
    }

    /// Skip button face: `+1s`, `−5m`, `+0.5s`.
    static func seek(_ s: Double) -> String {
        let m = abs(s), sign = s < 0 ? "−" : "+"
        if m >= 60, m.truncatingRemainder(dividingBy: 60) == 0 { return "\(sign)\(Int(m / 60))m" }
        return m == m.rounded() ? "\(sign)\(Int(m))s" : String(format: "%@%.1fs", sign, m)
    }

    /// Settings row value: `5 min`, `1 sec`, `0.5 sec`.
    static func duration(_ s: Double) -> String {
        if s >= 60, s.truncatingRemainder(dividingBy: 60) == 0 { return "\(Int(s / 60)) min" }
        return s == s.rounded() ? "\(Int(s)) sec" : String(format: "%.1f sec", s)
    }
}
