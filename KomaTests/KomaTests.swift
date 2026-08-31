import XCTest
import SwiftUI
import AVFoundation

/// The logic that can be wrong without anyone noticing: number formatting the buttons
/// depend on, the marks blob, and the transient picker. The view layer is not tested —
/// you can see that one.
final class FmtTests: XCTestCase {
    func testTimecodeIsMinutesSecondsMillis() {
        XCTAssertEqual(Fmt.timecode(0), "00:00.000")
        XCTAssertEqual(Fmt.timecode(67.694), "01:07.694")
        XCTAssertEqual(Fmt.timecode(876.31), "14:36.310")
    }

    /// A negative time means we seeked before the start; it must not render "-1:-0".
    func testTimecodeClampsNegative() {
        XCTAssertEqual(Fmt.timecode(-5), "00:00.000")
    }

    func testSeekLabelPicksMinutesOnlyOnWholeMinutes() {
        XCTAssertEqual(Fmt.seek(1), "+1s")
        XCTAssertEqual(Fmt.seek(-1), "−1s")
        XCTAssertEqual(Fmt.seek(60), "+1m")
        XCTAssertEqual(Fmt.seek(-300), "−5m")
        XCTAssertEqual(Fmt.seek(90), "+90s")     // not "+1.5m"
        XCTAssertEqual(Fmt.seek(0.5), "+0.5s")
    }

    func testDurationLabel() {
        XCTAssertEqual(Fmt.duration(1), "1 sec")
        XCTAssertEqual(Fmt.duration(0.5), "0.5 sec")
        XCTAssertEqual(Fmt.duration(300), "5 min")
        XCTAssertEqual(Fmt.duration(90), "90 sec")
    }
}

final class KnobTests: XCTestCase {
    func testEveryKnobDefaultSitsInsideItsSliderRange() {
        for k in Knobs.all {
            XCTAssertTrue(k.range.contains(k.def), "\(k.key) default \(k.def) is outside \(k.range)")
        }
    }

    func testKeysAreUnique() {
        let keys = Knobs.all.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testResetWritesEveryKnobAndLeavesMarksAlone() {
        let d = UserDefaults(suiteName: "KomaTests.reset")!
        d.removePersistentDomain(forName: "KomaTests.reset")
        for k in Knobs.all { d.set(k.def + 1, forKey: k.key) }
        d.set("{\"clip\":[1.0]}", forKey: Knobs.marksStore.key)

        Knobs.reset(d)

        for k in Knobs.all { XCTAssertEqual(d.double(forKey: k.key), k.def, k.key) }
        XCTAssertEqual(d.string(forKey: Knobs.marksStore.key), "{\"clip\":[1.0]}")
    }
}

final class MarkStoreTests: XCTestCase {
    func testRoundTrip() {
        let json = MarkStore.setting([1.5, 2.5], for: "clipA", in: "{}")
        XCTAssertEqual(MarkStore.marks(for: "clipA", in: json), [1.5, 2.5])
    }

    func testClipsDoNotShareMarks() {
        var json = MarkStore.setting([1], for: "a", in: "{}")
        json = MarkStore.setting([9], for: "b", in: json)
        XCTAssertEqual(MarkStore.marks(for: "a", in: json), [1])
        XCTAssertEqual(MarkStore.marks(for: "b", in: json), [9])
    }

    /// Videos we could not identify must not pool their marks under one empty key.
    func testEmptyClipIDIsNotStored() {
        XCTAssertEqual(MarkStore.setting([1, 2], for: "", in: "{}"), "{}")
    }

    func testGarbageStoreDecodesEmptyRatherThanCrashing() {
        XCTAssertEqual(MarkStore.marks(for: "a", in: "not json"), [])
        XCTAssertEqual(MarkStore.decode(""), [:])
    }

    func testToggleAddsThenRemovesWithinAFrameOfTolerance() {
        let fps = 60.0
        var m = MarkStore.toggle([], at: 1.0, fps: fps)
        XCTAssertEqual(m, [1.0])
        // A second tap lands a fraction of a frame off but means the same mark.
        m = MarkStore.toggle(m, at: 1.0 + 0.5 / fps, fps: fps)
        XCTAssertEqual(m, [])
    }

    func testToggleKeepsMarksSorted() {
        var m = MarkStore.toggle([], at: 5, fps: 60)
        m = MarkStore.toggle(m, at: 1, fps: 60)
        XCTAssertEqual(m, [1, 5])
    }

    func testNextSkipsThePointYouAreStandingOn() {
        let pois = [1.0, 2.0, 3.0]
        XCTAssertEqual(MarkStore.next(after: 2.0, in: pois, dir: 1, fps: 60), 3.0)
        XCTAssertEqual(MarkStore.next(after: 2.0, in: pois, dir: -1, fps: 60), 1.0)
        XCTAssertNil(MarkStore.next(after: 3.0, in: pois, dir: 1, fps: 60))
        XCTAssertNil(MarkStore.next(after: 1.0, in: pois, dir: -1, fps: 60))
    }

    func testNextWorksOnUnsortedInput() {
        XCTAssertEqual(MarkStore.next(after: 0, in: [3.0, 1.0, 2.0], dir: 1, fps: 60), 1.0)
    }
}

final class HitsTests: XCTestCase {
    /// hop of 0.01s keeps the arithmetic readable: index i is at i/100 seconds.
    private let hop = 0.01

    private func envelope(quiet: Float, spikesAt: [Int], spike: Float, length: Int) -> [Float] {
        var e = [Float](repeating: quiet, count: length)
        for i in spikesAt { e[i] = spike }
        return e
    }

    func testFindsASpikeAboveTheBackground() {
        let env = envelope(quiet: 0.01, spikesAt: [200], spike: 0.9, length: 400)
        let hits = Hits.pick(env, hop: hop, sensitivity: 2.5)
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first ?? -1, 2.0, accuracy: 0.001)
    }

    /// Steady loud hall noise is not a hit — that is the whole point of tracking a
    /// running background instead of thresholding on volume.
    func testSustainedLoudnessIsNotAHit() {
        let env = [Float](repeating: 0.6, count: 400)
        XCTAssertTrue(Hits.pick(env, hop: hop, sensitivity: 2.5).count < 3,
                      "a constant tone should not read as a rally of hits")
    }

    func testQuietSpikeBelowTheFloorIsIgnored() {
        let env = envelope(quiet: 0.001, spikesAt: [200], spike: 0.02, length: 400)
        XCTAssertEqual(Hits.pick(env, hop: hop, sensitivity: 2.5), [])
    }

    /// One contact rings for several windows; without spacing it counts as many hits.
    func testAdjacentSpikesCollapseToOne() {
        let env = envelope(quiet: 0.01, spikesAt: [200, 201, 202], spike: 0.9, length: 400)
        XCTAssertEqual(Hits.pick(env, hop: hop, sensitivity: 2.5).count, 1)
    }

    func testSpikesFurtherApartThanMinGapBothCount() {
        let env = envelope(quiet: 0.01, spikesAt: [100, 200], spike: 0.9, length: 400)
        XCTAssertEqual(Hits.pick(env, hop: hop, sensitivity: 2.5).count, 2)
    }

    func testHigherSensitivityFindsNoMoreHits() {
        let env = envelope(quiet: 0.02, spikesAt: [100, 200, 300], spike: 0.3, length: 400)
        let loose = Hits.pick(env, hop: hop, sensitivity: 2.0).count
        let strict = Hits.pick(env, hop: hop, sensitivity: 6.0).count
        XCTAssertLessThanOrEqual(strict, loose)
    }

    func testEmptyAudioFindsNothing() {
        XCTAssertEqual(Hits.pick([], hop: hop, sensitivity: 2.5), [])
    }
}


// MARK: - Localisation

final class LangTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: Lang.key)
        UserDefaults.standard.removeObject(forKey: Skin.key)
    }
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: Lang.key)
        UserDefaults.standard.removeObject(forKey: Skin.key)
        super.tearDown()
    }

    func testDefaultsToEnglishAndSurvivesGarbage() {
        XCTAssertEqual(Lang.current, .en)
        UserDefaults.standard.set("klingon", forKey: Lang.key)
        XCTAssertEqual(Lang.current, .en)
    }

    func testLanguageNames() {
        XCTAssertEqual(Lang.en.name, "English")
        XCTAssertEqual(Lang.vi.name, "Tiếng Việt")
        XCTAssertEqual(Lang.allCases.count, 2)
    }

    func testEnglishPassesTextStraightThrough() {
        XCTAssertEqual(L("Settings"), "Settings")
        XCTAssertEqual(L("nothing will ever translate this"), "nothing will ever translate this")
    }

    func testVietnameseTranslatesAndFallsBackToEnglish() {
        UserDefaults.standard.set(Lang.vi.rawValue, forKey: Lang.key)
        XCTAssertEqual(L("Settings"), "Cài đặt")
        // The failure mode that matters: an untranslated string must stay readable.
        XCTAssertEqual(L("Untranslated thing"), "Untranslated thing")
    }

    /// A translation identical to its key is a copy-paste slip, not a translation.
    func testNoVietnameseEntryIsJustTheEnglishBack() {
        UserDefaults.standard.set(Lang.vi.rawValue, forKey: Lang.key)
        for key in ["Settings", "Done", "Cancel", "Mark", "Speed", "Zoom", "Volume"] {
            XCTAssertNotEqual(L(key), key, "\(key) is missing a Vietnamese translation")
        }
    }

    func testSkinDefaultsToDarkAndSurvivesGarbage() {
        XCTAssertEqual(Skin.current, .dark)
        UserDefaults.standard.set("chartreuse", forKey: Skin.key)
        XCTAssertEqual(Skin.current, .dark)
        UserDefaults.standard.set(Skin.light.rawValue, forKey: Skin.key)
        XCTAssertEqual(Skin.current, .light)
    }

    func testSkinColorSchemes() {
        XCTAssertNil(Skin.system.scheme)
        XCTAssertEqual(Skin.light.scheme, .light)
        XCTAssertEqual(Skin.dark.scheme, .dark)
    }

    func testSkinNamesTranslate() {
        XCTAssertEqual(Skin.system.name, "System")
        UserDefaults.standard.set(Lang.vi.rawValue, forKey: Lang.key)
        XCTAssertEqual(Skin.system.name, "Theo hệ thống")
        XCTAssertEqual(Skin.light.name, "Sáng")
        XCTAssertEqual(Skin.dark.name, "Tối")
    }
}

// MARK: - Reading real audio

final class HitsAudioTests: XCTestCase {
    /// A two-second silent tone with one click in it, written to disk — the only way to
    /// exercise the AVAssetReader path, and cheap enough to build per test.
    private func clipWithClicks(at times: [Double], duration: Double = 2) throws -> AVAsset {
        let rate = 44100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)!
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("koma-\(times.count)-\(duration).wav")
        try? FileManager.default.removeItem(at: url)

        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(rate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) { samples[i] = 0.002 }   // near-silent room tone
        for t in times {
            let start = Int(t * rate)
            for i in start..<min(start + 200, Int(frames)) { samples[i] = 0.9 }
        }
        try file.write(from: buffer)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return AVURLAsset(url: url)
    }

    func testFindsTheClickInARealFile() async throws {
        var progress: [Double] = []
        let hits = try await Hits.find(in: clipWithClicks(at: [1.0]), sensitivity: 2.5) {
            progress.append($0)
        }
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(try XCTUnwrap(hits.first), 1.0, accuracy: 0.05)
        XCTAssertEqual(progress.last, 1, "progress must finish at 100%")
        XCTAssertFalse(progress.contains { $0 > 1 })
    }

    func testFindsBothClicksAndKeepsThemInOrder() async throws {
        let hits = try await Hits.find(in: clipWithClicks(at: [0.5, 1.5]), sensitivity: 2.5) { _ in }
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits, hits.sorted())
    }

    func testSilenceHasNoHits() async throws {
        let hits = try await Hits.find(in: clipWithClicks(at: []), sensitivity: 2.5) { _ in }
        XCTAssertTrue(hits.isEmpty)
    }

    /// A video with no audio track must return nothing, not throw.
    func testAssetWithoutAudioFindsNothing() async throws {
        let hits = try await Hits.find(in: AVMutableComposition(), sensitivity: 2.5) { _ in }
        XCTAssertTrue(hits.isEmpty)
    }
}

// MARK: - History

final class HistoryStoreTests: XCTestCase {
    func testRecordsNewestFirstAndUpdatesInPlace() {
        var json = "[]"
        json = HistoryStore.record("a", at: 5, duration: 60, openedAt: 1, in: json)
        json = HistoryStore.record("b", at: 7, duration: 60, openedAt: 2, in: json)
        json = HistoryStore.record("a", at: 9, duration: 60, openedAt: 3, in: json)

        let list = HistoryStore.decode(json)
        XCTAssertEqual(list.map(\.id), ["a", "b"])          // reopened clip moves to the top
        XCTAssertEqual(list.count, 2)                        // and does not duplicate
        XCTAssertEqual(HistoryStore.position(for: "a", in: json), 9)
    }

    /// Without an identifier every clip would share one row and overwrite each other.
    func testEmptyIdIsNotRecorded() {
        let json = HistoryStore.record("", at: 5, duration: 60, openedAt: 1, in: "[]")
        XCTAssertTrue(HistoryStore.decode(json).isEmpty)
    }

    func testKeepsOnlyTheMostRecent() {
        var json = "[]"
        for i in 0..<(HistoryStore.limit + 5) {
            json = HistoryStore.record("clip\(i)", at: 1, duration: 60, openedAt: Double(i), in: json)
        }
        let list = HistoryStore.decode(json)
        XCTAssertEqual(list.count, HistoryStore.limit)
        XCTAssertEqual(list.first?.id, "clip\(HistoryStore.limit + 4)")
    }

    func testUnknownClipHasNoPosition() {
        XCTAssertEqual(HistoryStore.position(for: "nope", in: "[]"), 0)
    }

    func testRemove() {
        let json = HistoryStore.record("a", at: 5, duration: 60, openedAt: 1, in: "[]")
        XCTAssertTrue(HistoryStore.decode(HistoryStore.remove("a", in: json)).isEmpty)
    }
}

// MARK: - Hits-only video

final class ReelTests: XCTestCase {
    private func ranges(_ hits: [Double], before: Double = 0.5, after: Double = 1,
                        duration: Double = 100) -> [(start: Double, end: Double)] {
        Reel.ranges(hits: hits, before: before, after: after, duration: duration)
    }

    func testOneWindowPerIsolatedHit() {
        let r = ranges([10, 50])
        XCTAssertEqual(r.count, 2)
        XCTAssertEqual(r[0].start, 9.5)
        XCTAssertEqual(r[0].end, 11)
    }

    /// A fast exchange must come out as one continuous piece, not a stutter of cuts.
    func testOverlappingWindowsMerge() {
        let r = ranges([10, 10.4, 10.9])
        XCTAssertEqual(r.count, 1)
        XCTAssertEqual(r[0].start, 9.5)
        XCTAssertEqual(r[0].end, 11.9)
    }

    func testClampsToTheClip() {
        let r = ranges([0.1, 99.9], duration: 100)
        XCTAssertEqual(r[0].start, 0)
        XCTAssertEqual(r[1].end, 100)
    }

    func testUnsortedHitsStillProduceOrderedRanges() {
        let r = ranges([50, 10, 30])
        XCTAssertEqual(r.map(\.start), [9.5, 29.5, 49.5])
    }

    func testNoHitsNoRanges() {
        XCTAssertTrue(ranges([]).isEmpty)
    }

    func testStepKeepsPlayingInsideAWindow() {
        let r = ranges([10, 50])
        XCTAssertEqual(Reel.step(at: 10.2, in: r), .keepPlaying)
        XCTAssertEqual(Reel.step(at: 9.5, in: r), .keepPlaying)
    }

    func testStepJumpsOverTheDeadTime() {
        XCTAssertEqual(Reel.step(at: 20, in: ranges([10, 50])), .seek(49.5))
        XCTAssertEqual(Reel.step(at: 0, in: ranges([10])), .seek(9.5))
    }

    func testStepEndsAfterTheLastHit() {
        XCTAssertEqual(Reel.step(at: 80, in: ranges([10, 50])), .end)
        XCTAssertEqual(Reel.step(at: 0, in: ranges([])), .end)
    }

    /// Landing a millisecond past a window must not silently skip the next one.
    func testStepDoesNotSkipAWindowItLandsOnTheEdgeOf() {
        XCTAssertEqual(Reel.step(at: 11.4, in: ranges([10, 50])), .seek(49.5))
    }

    func testTotalLengthIsTheSumOfTheMergedPieces() {
        // 9.5...11.4 merged, not two separate 1.5s windows.
        XCTAssertEqual(Reel.totalLength(ranges([10, 10.4])), 1.9, accuracy: 0.0001)
    }
}



// MARK: - Voice spans

final class VoiceTests: XCTestCase {
    private func eq(_ got: [(Double, Double)], _ want: [(Double, Double)],
                    _ file: StaticString = #filePath, _ line: UInt = #line) {
        XCTAssertEqual(got.map(\.0), want.map(\.0), file: file, line: line)
        XCTAssertEqual(got.map(\.1), want.map(\.1), file: file, line: line)
    }

    /// A sentence arrives as a run of adjacent classifier windows; one silence, not ten.
    func testAdjacentWindowsBecomeOneSpan() {
        eq(Voice.merge([(1.0, 1.5), (1.5, 2.0), (2.0, 2.5)]), [(1.0, 2.5)])
    }

    func testSeparateUtterancesStaySeparate() {
        eq(Voice.merge([(1.0, 1.5), (9.0, 9.5)]), [(1.0, 1.5), (9.0, 9.5)])
    }

    func testGapWithinToleranceCloses() {
        eq(Voice.merge([(1.0, 1.5), (1.65, 2.0)]), [(1.0, 2.0)])
        eq(Voice.merge([(1.0, 1.5), (1.9, 2.0)]), [(1.0, 1.5), (1.9, 2.0)])
    }

    func testUnsortedInputMergesAnyway() {
        eq(Voice.merge([(9.0, 9.5), (1.0, 1.5), (1.5, 2.0)]), [(1.0, 2.0), (9.0, 9.5)])
    }

    /// A span swallowed by a longer one must not shorten it.
    func testNestedSpanDoesNotShortenTheOuterOne() {
        eq(Voice.merge([(1.0, 5.0), (2.0, 3.0)]), [(1.0, 5.0)])
    }

    /// The bug that shipped: speech is present but ranked below the room itself,
    /// so looking only at the top label found nothing and the filter did nothing.
    func testSpeechCountsEvenWhenItIsNotTheTopLabel() {
        let labels = [("crowd_noise", 0.71), ("applause", 0.44), ("speech", 0.38)]
        XCTAssertTrue(Voice.isVoice(labels, confidence: 0.3))
    }

    func testBelowConfidenceIsNotAVoice() {
        XCTAssertFalse(Voice.isVoice([("speech", 0.12)], confidence: 0.3))
    }

    func testCourtSoundsAreNotVoices() {
        XCTAssertFalse(Voice.isVoice([("inside_large_room", 0.9), ("squeak", 0.5)],
                                     confidence: 0.3))
    }

    func testNoLabelsIsNotAVoice() {
        XCTAssertFalse(Voice.isVoice([], confidence: 0.3))
    }

    func testNothingToMerge() {
        XCTAssertTrue(Voice.merge([]).isEmpty)
    }

    /// No voice found means leave the audio alone — a mix that silences nothing is
    /// still a mix, and attaching one would be a pointless render pass.
    func testNoSpansMeansNoMix() async throws {
        let asset = AVMutableComposition()
        let track = asset.addMutableTrack(withMediaType: .audio,
                                          preferredTrackID: kCMPersistentTrackID_Invalid)!
        XCTAssertNil(Voice.mix(muting: [], on: track))
        XCTAssertNotNil(Voice.mix(muting: [(1, 2)], on: track))
    }

    func testSpansOfANonFileAssetAreEmptyRatherThanACrash() async {
        let spans = await Voice.spans(in: AVMutableComposition(), confidence: 0.6)
        XCTAssertTrue(spans.isEmpty)
    }
}
