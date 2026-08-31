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

    /// Drops any candidate that lands inside a window the classifier calls a voice.
    /// Returns the input unchanged on any failure — a broken filter must never cost you hits.
    static func keep(_ hits: [Double], in asset: AVAsset, confidence: Double) async -> [Double] {
        guard !hits.isEmpty, let url = (asset as? AVURLAsset)?.url else { return hits }
        guard let spans = try? await voiceSpans(url, confidence: confidence), !spans.isEmpty else { return hits }
        return hits.filter { at in !spans.contains { at >= $0.0 && at <= $0.1 } }
    }

    private static func voiceSpans(_ url: URL, confidence: Double) async throws -> [(Double, Double)] {
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
                  let top = r.classifications.first,
                  top.confidence >= confidence,
                  Voice.noise.contains(where: { top.identifier.lowercased().contains($0) })
            else { return }
            spans.append((r.timeRange.start.seconds, r.timeRange.end.seconds))
        }
    }
}
