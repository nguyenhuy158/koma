import AVFoundation

/// Finds racket-shuttle contacts by their sound. The hit is a sharp transient — far easier
/// to spot in audio than in pixels, and it lands on the exact frame you want to see.
enum Hits {
    static let sampleRate = 22050.0
    static let window = 256                 // ~12ms per envelope point

    static func find(in asset: AVAsset, sensitivity: Double,
                     progress: @escaping (Double) -> Void) async throws -> [Double] {
        let env = try await envelope(of: asset, progress: progress)
        return pick(env, hop: Double(window) / sampleRate, sensitivity: sensitivity)
    }

    /// Peak amplitude per window — enough to see a transient, ~86x smaller than the audio.
    private static func envelope(of asset: AVAsset,
                                 progress: @escaping (Double) -> Void) async throws -> [Float] {
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let total = try await asset.load(.duration).seconds

        let reader = try AVAssetReader(asset: asset)
        let out = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
        ])
        guard reader.canAdd(out) else { return [] }
        reader.add(out)
        reader.startReading()
        defer { reader.cancelReading() }

        var env: [Float] = []
        while !Task.isCancelled, let sb = out.copyNextSampleBuffer() {
            if let bb = CMSampleBufferGetDataBuffer(sb) {
                var len = 0
                var ptr: UnsafeMutablePointer<Int8>?
                CMBlockBufferGetDataPointer(bb, atOffset: 0, lengthAtOffsetOut: nil,
                                            totalLengthOut: &len, dataPointerOut: &ptr)
                if let p = ptr {
                    let n = len / 2
                    p.withMemoryRebound(to: Int16.self, capacity: n) { s in
                        var i = 0
                        while i < n {
                            var peak: Float = 0
                            let end = min(i + window, n)
                            while i < end {
                                peak = max(peak, abs(Float(s[i])))
                                i += 1
                            }
                            env.append(peak / 32768)
                        }
                    }
                }
            }
            CMSampleBufferInvalidate(sb)
            progress(min(0.95, Double(env.count) * Double(window) / sampleRate / max(total, 1)))
        }
        progress(1)
        return env
    }

    /// A hit is a sudden rise above the recent background, not merely a loud moment —
    /// otherwise shouting and hall noise score as high as the racket.
    /// ponytail: sensitivity, the 0.05 floor and the 0.35s spacing are the knobs that
    /// need real footage; a gym with a ceiling fan will not match a quiet hall.
    static func pick(_ env: [Float], hop: Double, sensitivity: Double,
                     floor: Float = 0.05, minGap: Double = 0.35) -> [Double] {
        var found: [Double] = []
        var background: Float = 0.001
        var last = -Double.infinity
        for (i, v) in env.enumerated() {
            let at = Double(i) * hop
            if v > background * Float(sensitivity), v > floor, at - last > minGap {
                found.append(at)
                last = at
            }
            background = background * 0.98 + v * 0.02
        }
        return found
    }
}
