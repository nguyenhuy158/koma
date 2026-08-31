import SwiftUI

/// The knobs that actually need tuning. Nothing here has a value that works for
/// every clip — 240fps footage wants different numbers than a 30fps phone video.
/// Every default comes from `Knobs`; none is written out again here.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage(Knobs.ptsPerFrame.key) private var ptsPerFrame = Knobs.ptsPerFrame.def
    @AppStorage(Knobs.holdRate.key)    private var holdRate    = Knobs.holdRate.def
    @AppStorage(Knobs.smallSeek.key)   private var smallSeek   = Knobs.smallSeek.def
    @AppStorage(Knobs.bigSeek.key)     private var bigSeek     = Knobs.bigSeek.def
    @AppStorage(Knobs.hugeSeek.key)    private var hugeSeek    = Knobs.hugeSeek.def
    @AppStorage(Knobs.onionCount.key)  private var onionCount  = Knobs.onionCount.def
    @AppStorage(Knobs.hitSense.key)    private var hitSense    = Knobs.hitSense.def
    @AppStorage(Knobs.voiceFilter.key) private var voiceFilter = Knobs.voiceFilter.def
    @AppStorage(Knobs.voiceConf.key)   private var voiceConf   = Knobs.voiceConf.def
    @AppStorage(Knobs.haptics.key)     private var haptics     = Knobs.haptics.def
    @AppStorage(Knobs.keepAwake.key)   private var keepAwake   = Knobs.keepAwake.def
    @AppStorage(Knobs.volume.key)      private var volume      = Knobs.volume.def
    @AppStorage(Knobs.reelBefore.key)  private var reelBefore  = Knobs.reelBefore.def
    @AppStorage(Knobs.reelAfter.key)   private var reelAfter   = Knobs.reelAfter.def
    @AppStorage(Lang.key)              private var lang        = Lang.en.rawValue
    @AppStorage(Skin.key)              private var skin        = Skin.dark.rawValue

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    knob(L("Drag sensitivity"), "\(Int(ptsPerFrame)) pt / frame",
                         $ptsPerFrame, Knobs.ptsPerFrame)
                    knob(L("Hold speed"), "\(Int(holdRate)) frames / sec",
                         $holdRate, Knobs.holdRate)
                } header: {
                    Text(L("Stepping"))
                } footer: {
                    Text(L("Drag across the video to scrub. Hold a step button to run."))
                }

                Section(L("Skip buttons")) {
                    knob(L("Small skip"), Fmt.duration(smallSeek), $smallSeek, Knobs.smallSeek)
                    knob(L("Large skip"), Fmt.duration(bigSeek), $bigSeek, Knobs.bigSeek)
                    knob(L("Huge skip"), Fmt.duration(hugeSeek), $hugeSeek, Knobs.hugeSeek)
                }

                Section {
                    knob(L("Onion skin frames"), "\(Int(onionCount)) frames",
                         $onionCount, Knobs.onionCount)
                    knob(L("Hit sensitivity"), String(format: "%.1f×", hitSense),
                         $hitSense, Knobs.hitSense)
                    Toggle(L("Ignore voices"), isOn: $voiceFilter)
                    if voiceFilter {
                        knob(L("Voice confidence"), "\(Int(voiceConf * 100))%", $voiceConf, Knobs.voiceConf)
                    }
                } header: {
                    Text(L("Analysis"))
                } footer: {
                    Text(L("Lower sensitivity finds more hits and more false ones. Tune it on real court footage — hall noise differs everywhere."))
                    Text(L("Ignore voices runs a second pass that drops hits landing on speech or laughter. It can also drop a real hit if someone shouts during the rally — raise the confidence if that happens."))
                }

                Section {
                    knob(L("Before each hit"), Fmt.duration(reelBefore), $reelBefore, Knobs.reelBefore)
                    knob(L("After each hit"), Fmt.duration(reelAfter), $reelAfter, Knobs.reelAfter)
                } header: {
                    Text(L("Hits-only video"))
                } footer: {
                    Text(L("How much of the clip to keep around each hit. Windows that overlap are joined, so a fast exchange stays in one piece."))
                }

                Section(L("Playback")) {
                    knob(L("Volume"), "\(Int(volume * 100))%", $volume, Knobs.volume)
                    Toggle(L("Haptic on each frame"), isOn: $haptics)
                    Toggle(L("Keep screen awake"), isOn: $keepAwake)
                }

                Section(L("Appearance")) {
                    Picker(L("Appearance"), selection: $skin) {
                        ForEach(Skin.allCases, id: \.rawValue) { Text($0.name).tag($0.rawValue) }
                    }
                    Picker(L("Language"), selection: $lang) {
                        ForEach(Lang.allCases, id: \.rawValue) { Text($0.name).tag($0.rawValue) }
                    }
                }

                Section {
                    // Writes through UserDefaults from the table — adding a knob above
                    // does not mean remembering to add a line here.
                    Button(L("Reset to defaults"), role: .destructive) { Knobs.reset() }
                }
            }
            .navigationTitle(L("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(L("Done")) { dismiss() } }
        }
    }

    private func knob(_ title: String, _ value: String,
                      _ binding: Binding<Double>, _ k: Knob) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(value).font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: binding, in: k.range, step: k.step).tint(.orange)
        }
        .padding(.vertical, 2)
    }
}

#Preview { SettingsView() }
