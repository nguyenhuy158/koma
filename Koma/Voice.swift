import AVFoundation
import SoundAnalysis

/// C1-i — a veto pass, not a detector. `Hits.pick` only knows how loud a moment is, so a
/// laugh or a shout scores like a racket. Apple's built-in classifier knows what a voice
/// sounds like but has no idea what a racket sounds like — so it is only used to *drop*
/// candidates the amplitude pass already found. Hits.swift is untouched by this.
enum Voice {
    /// Labels in the `.version1` classifier that a badminton hit is never confused with.
    /// Substring match: the exact identifiers vary between OS versions.
    static let noise = ["speech", "laugh", "shout", "yell", "chatter", "conversation",
                        "singing", "cheer", "whisper", "crowd"]

    /// True when any label the classifier ranked is a voice above `confidence`.
    ///
    /// Not `classifications.first`: in a sports hall the top label is the room itself —
    /// crowd, applause, "inside, large room" — and speech sits a few places below it
    /// while still being clearly present. Ranking first is a different question from
    /// being there, and the one we care about is the second.
    static func isVoice(_ labels: [(String, Double)], confidence: Double) -> Bool {
        labels.contains { id, c in
            c >= confidence && noise.contains(where: { id.lowercased().contains($0) })
        }
    }

    /// Drops any candidate that lands inside a window the classifier calls a voice.
    /// Returns the input unchanged on any failure — a broken filter must never cost you hits.
    static func keep(_ hits: [Double], in asset: AVAsset, confidence: Double) async -> [Double] {
        guard !hits.isEmpty, let url = (asset as? AVURLAsset)?.url else { return hits }
        guard let found = try? await spans(in: url, confidence: confidence), !found.isEmpty else { return hits }
        return hits.filter { at in !found.contains { at >= $0.0 && at <= $0.1 } }
    }

    /// The windows the classifier calls a voice, merged. Empty on any failure.
    static func spans(in asset: AVAsset, confidence: Double) async -> [(Double, Double)] {
        guard let url = (asset as? AVURLAsset)?.url else { return [] }
        return merge((try? await spans(in: url, confidence: confidence)) ?? [])
    }

    /// The classifier emits one window per analysis frame, so a sentence arrives as a
    /// run of adjacent windows. Merging them is what turns those into one silence.
    static func merge(_ spans: [(Double, Double)], gap: Double = 0.2) -> [(Double, Double)] {
        var out: [(Double, Double)] = []
        for s in spans.sorted(by: { $0.0 < $1.0 }) {
            if let last = out.last, s.0 - last.1 <= gap {
                out[out.count - 1].1 = max(last.1, s.1)
            } else {
                out.append(s)
            }
        }
        return out
    }

    /// Silences `spans` and leaves everything else at full volume. Ramped, because a
    /// hard cut to zero is an audible click — worse than the voice it removes.
    static func mix(muting spans: [(Double, Double)], on track: AVAssetTrack,
                    ramp: Double = 0.05) -> AVAudioMix? {
        guard !spans.isEmpty else { return nil }
        let p = AVMutableAudioMixInputParameters(track: track)
        p.setVolume(1, at: .zero)
        for s in spans {
            let start = max(0, s.0 - ramp), end = s.1 + ramp
            p.setVolumeRamp(fromStartVolume: 1, toEndVolume: 0, timeRange: range(start, s.0))
            p.setVolume(0, at: time(s.0))
            p.setVolumeRamp(fromStartVolume: 0, toEndVolume: 1, timeRange: range(s.1, end))
        }
        let mix = AVMutableAudioMix()
        mix.inputParameters = [p]
        return mix
    }

    private static func time(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 600) }
    private static func range(_ a: Double, _ b: Double) -> CMTimeRange {
        CMTimeRange(start: time(a), end: time(max(b, a + 0.001)))
    }

    private static func spans(in url: URL, confidence: Double) async throws -> [(Double, Double)] {
        let analyzer = try SNAudioFileAnalyzer(url: url)
        let request = try SNClassifySoundRequest(classifierIdentifier: .version1)
        let watcher = Watcher(confidence: confidence)
        try analyzer.add(request, withObserver: watcher)
        await withCheckedContinuation { go in
            analyzer.analyze { _ in go.resume() }
        }
        return watcher.spans
    }

    /// SoundAnalysis calls back on its own queue and only one analysis runs at a time,
    /// so a plain array behind the completion barrier is enough.
    private final class Watcher: NSObject, SNResultsObserving {
        var spans: [(Double, Double)] = []
        let confidence: Double

        init(confidence: Double) { self.confidence = confidence }

        func request(_ request: SNRequest, didProduce result: SNResult) {
            guard let r = result as? SNClassificationResult,
                  Voice.isVoice(r.classifications.map { ($0.identifier, $0.confidence) },
                                confidence: confidence)
            else { return }
            spans.append((r.timeRange.start.seconds, r.timeRange.end.seconds))
        }
    }
}
