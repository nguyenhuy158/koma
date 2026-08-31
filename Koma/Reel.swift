import AVFoundation

/// Builds a clip containing only the moments around each detected hit.
enum Reel {
    /// Windows around each hit, clamped to the clip and merged where they overlap.
    /// Merging matters: in a fast exchange the windows run together, and two
    /// separate cuts there would stutter across a rally that was continuous.
    ///
    /// Pure on purpose — this is the part worth testing.
    static func ranges(hits: [Double], before: Double, after: Double,
                       duration: Double) -> [(start: Double, end: Double)] {
        var out: [(start: Double, end: Double)] = []
        for h in hits.sorted() {
            let s = max(0, h - before), e = min(duration, h + after)
            guard e > s else { continue }
            if let last = out.last, s <= last.end {
                out[out.count - 1].end = max(last.end, e)
            } else {
                out.append((s, e))
            }
        }
        return out
    }

    /// What playback should do at time `t` when only the hits are wanted.
    /// Pure so the skipping rule is testable without a player.
    enum Step: Equatable { case keepPlaying, seek(Double), end }

    static func step(at t: Double, in ranges: [(start: Double, end: Double)]) -> Step {
        // A hair of slack: the time observer fires a few ms late, and landing 0.001s
        // past the end of a window would otherwise skip the next one entirely.
        if ranges.contains(where: { t >= $0.start - 0.02 && t < $0.end }) { return .keepPlaying }
        if let next = ranges.first(where: { $0.start > t }) { return .seek(next.start) }
        return .end
    }

    static func totalLength(_ ranges: [(start: Double, end: Double)]) -> Double {
        ranges.reduce(0) { $0 + ($1.end - $1.start) }
    }

    /// Video + audio stitched back to back. The hit sound is half the point, so a
    /// video-only composition would be the wrong shortcut here.
    static func compose(_ asset: AVAsset,
                        _ ranges: [(start: Double, end: Double)]) async throws -> AVComposition {
        let comp = AVMutableComposition()
        let video = try await asset.loadTracks(withMediaType: .video).first
        let audio = try await asset.loadTracks(withMediaType: .audio).first
        guard let video else { throw Err.noVideo }

        let vOut = comp.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let aOut = audio == nil ? nil
            : comp.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        // Without this a portrait clip exports on its side.
        vOut?.preferredTransform = try await video.load(.preferredTransform)

        var at = CMTime.zero
        for r in ranges {
            let range = CMTimeRange(
                start: CMTime(seconds: r.start, preferredTimescale: 600),
                end: CMTime(seconds: r.end, preferredTimescale: 600))
            try vOut?.insertTimeRange(range, of: video, at: at)
            if let audio, let aOut { try? aOut.insertTimeRange(range, of: audio, at: at) }
            at = at + range.duration
        }
        return comp
    }

    /// Writes to `url`, reporting 0…1. Passthrough preset: no re-encode, so a
    /// 240fps clip stays 240fps and the export is I/O bound rather than CPU bound.
    static func export(_ comp: AVComposition, to url: URL,
                       progress: @escaping (Double) -> Void) async throws {
        try? FileManager.default.removeItem(at: url)
        guard let session = AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetPassthrough)
                ?? AVAssetExportSession(asset: comp, presetName: AVAssetExportPresetHighestQuality)
        else { throw Err.noExporter }
        session.outputURL = url
        session.outputFileType = .mov
        session.shouldOptimizeForNetworkUse = false

        let ticker = Task {
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        defer { ticker.cancel() }

        await session.export()
        switch session.status {
        case .completed: progress(1)
        case .cancelled: throw CancellationError()
        default: throw session.error ?? Err.failed
        }
    }

    enum Err: LocalizedError {
        case noVideo, noExporter, failed
        var errorDescription: String? {
            switch self {
            case .noVideo:    return L("That clip has no video track.")
            case .noExporter: return L("Couldn't start the export.")
            case .failed:     return L("Export failed.")
            }
        }
    }
}
