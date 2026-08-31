import SwiftUI
import AVKit
import PhotosUI
import Photos

// Frame-by-frame video review. Main feature: step exactly one frame.
// AVPlayerItem.step(byCount:) does this natively — no image extraction pipeline.

struct ContentView: View {
    @State private var player = AVPlayer()
    @State private var pick: PhotosPickerItem?
    @State private var loaded = false
    @State private var loading = false
    @State private var problem: String?
    @State private var progress: Double = 0
    @State private var rate: Float = 0
    @State private var current: Double = 0
    @State private var duration: Double = 0
    @State private var fps: Double = 30
    @State private var scrubbing = false
    @State private var dragFrames = 0
    @State private var zoom: CGFloat = 1
    @State private var zoomBase: CGFloat = 1
    @State private var pan: CGSize = .zero
    @State private var panBase: CGSize = .zero
    @State private var locked = false
    @State private var loadTask: Task<Void, Never>?
    @State private var requestID = PHInvalidImageRequestID
    @State private var elapsed = 0
    @State private var observer: Any?
    @State private var showSettings = false
    @State private var showHelp = false
    @State private var clipID = ""
    @State private var marks: [Double] = []
    @State private var hits: [Double] = []
    @State private var analyzing = false
    @State private var analyzeProgress: Double = 0
    @State private var analyzeTask: Task<Void, Never>?
    @State private var loopA: Double?
    @State private var loopB: Double?
    @State private var speed: Double = 1
    @State private var onion = false
    @State private var ghosts: [UIImage] = []
    @State private var ghostTask: Task<Void, Never>?
    @State private var generator: AVAssetImageGenerator?
    @State private var shareImage: UIImage?

    // Court footage varies too much for fixed values. Defaults live in Knobs, once.
    @AppStorage(Knobs.ptsPerFrame.key) private var ptsPerFrame = Knobs.ptsPerFrame.def
    @AppStorage(Knobs.holdRate.key)    private var holdRate    = Knobs.holdRate.def
    @AppStorage(Knobs.smallSeek.key)   private var smallSeek   = Knobs.smallSeek.def
    @AppStorage(Knobs.bigSeek.key)     private var bigSeek     = Knobs.bigSeek.def
    @AppStorage(Knobs.hugeSeek.key)    private var hugeSeek    = Knobs.hugeSeek.def
    @AppStorage(Knobs.onionCount.key)  private var onionCount  = Knobs.onionCount.def
    @AppStorage(Knobs.hitSense.key)    private var hitSense    = Knobs.hitSense.def
    @AppStorage(Knobs.haptics.key)     private var haptics     = Knobs.haptics.def
    @AppStorage(Knobs.keepAwake.key)   private var keepAwake   = Knobs.keepAwake.def
    @AppStorage(Knobs.marksStore.key)  private var marksStore  = Knobs.marksStore.def
    @AppStorage(Knobs.volume.key)      private var volume      = Knobs.volume.def
    // Read so the whole screen re-renders when either is changed in Settings.
    @AppStorage(Lang.key)              private var lang        = Lang.en.rawValue
    @AppStorage(Skin.key)              private var skin        = Skin.dark.rawValue

    private var playing: Bool { rate != 0 }
    private var frameIndex: Int { Int((current * fps).rounded()) }
    private var frameCount: Int { Int((duration * fps).rounded()) }

    var body: some View {
        VStack(spacing: 0) {
            video
            if loaded { readout; timeline }
            controls
        }
        .background(Color(.systemBackground))
        .preferredColorScheme(Skin.current.scheme)
        .persistentSystemOverlays(.hidden)
        .statusBarHidden()
        .task { start(); await askPhotos() }
        // Single-param form: the iOS 17 two-param onChange would break our 16.0 target.
        .onChange(of: pick) { new in
            loadTask?.cancel()
            loadTask = Task { await load(new) }
        }
        .onReceive(player.publisher(for: \.rate)) { rate = $0 }
        .onChange(of: keepAwake) { UIApplication.shared.isIdleTimerDisabled = $0 }
        .onChange(of: volume) { player.volume = Float($0) }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showHelp) { HelpView() }
        .sheet(isPresented: Binding(get: { shareImage != nil },
                                    set: { if !$0 { shareImage = nil } })) {
            if let img = shareImage { ActivityView(items: [img]) }
        }
        .onChange(of: current) { _ in scheduleGhosts() }
        .onChange(of: onion) { _ in scheduleGhosts() }
    }

    private var gear: some View {
        HStack(spacing: 14) {
            Button { showHelp = true } label: { Image(systemName: "questionmark.circle") }
            Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
        }
    }

    // MARK: - Video

    private var video: some View {
        GeometryReader { geo in
            PlayerLayerView(player: player)
                .overlay { ghostOverlay }
                .scaleEffect(zoom)
                .offset(pan)
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(SimultaneousGesture(pinch(geo.size), drag(geo.size)))
                // Only ever covers an empty screen — a stuck flag must never hide a loaded video.
                .overlay { if !loaded { loading ? AnyView(loadingState) : AnyView(emptyState) } }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Earlier frames stacked faintly on the current one: one still shows where the racket
    /// is, three show where it is going.
    private var ghostOverlay: some View {
        ZStack {
            ForEach(Array(ghosts.enumerated()).reversed(), id: \.offset) { i, img in
                Image(uiImage: img).resizable().scaledToFit()
                    .opacity(0.5 / Double(i + 2))
            }
        }
        .allowsHitTesting(false)
    }

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView().tint(.white).scaleEffect(1.4)
            if elapsed > 0 { Text("\(elapsed)s").font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.4)) }
            // Big slo-mo clips live in iCloud; without a number this looks like a hang.
            // progressHandler only fires for an iCloud download, so a number means exactly that.
            Text(progress > 0 ? "iCloud \(Int(progress * 100))%" : L("Opening…"))
                .font(.footnote.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
            Button(L("Cancel"), role: .cancel) { cancelLoad() }
                .buttonStyle(.bordered).tint(.white).padding(.top, 4)
        }
    }

    private func cancelLoad() {
        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            requestID = PHInvalidImageRequestID
        }
        loadTask?.cancel()
        loading = false
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film.stack").font(.system(size: 52, weight: .light))
            Text(L("Load a rally")).font(.title3.weight(.medium))
            Text(problem ?? L("Record at 120 or 240fps — more frames per swing."))
                .font(.footnote)
                .foregroundStyle(problem == nil ? .secondary : Color.orange)
                .multilineTextAlignment(.center)
            gear.font(.title3).padding(.top, 8)
        }
        .foregroundStyle(.white.opacity(0.75))
        .padding(32)
    }

    // MARK: - Readout

    /// Where you actually are. Frame stepping is useless without it.
    /// verbatim: plain interpolation, or a vi_VN locale renders frame 4056 as "4.056".
    private var readout: some View {
        HStack(spacing: 10) {
            Text(verbatim: "\(Fmt.timecode(current)) / \(Fmt.timecode(duration))")
            Spacer(minLength: 0)
            Text(verbatim: "f\(frameIndex)").foregroundStyle(.orange)
            Text(verbatim: "\(Int(fps.rounded()))fps").foregroundStyle(.secondary)
            // The hit sound is half the review, so muting needs to be one tap away.
            Button { volume = volume > 0 ? 0 : 1 } label: {
                Image(systemName: volume > 0 ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .foregroundStyle(volume > 0 ? Color.primary : .orange)
            picker { Image(systemName: "film") }
            gear
        }
        .font(.footnote.weight(.semibold))
        .font(.system(.caption, design: .monospaced).weight(.medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ticksBar
            slider
        }
        .padding(.horizontal, 20)
    }

    /// Marks and detected hits, where they actually sit in the clip.
    private var ticksBar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                ForEach(hits, id: \.self) { tick($0, g.size.width, .cyan, 6) }
                ForEach(marks, id: \.self) { tick($0, g.size.width, .orange, 10) }
            }
        }
        .frame(height: 10)
    }

    private func tick(_ t: Double, _ w: CGFloat, _ c: Color, _ h: CGFloat) -> some View {
        Rectangle().fill(c).frame(width: 2, height: h)
            .offset(x: w * CGFloat(t / max(duration, 0.01)))
    }

    private var slider: some View {
        Slider(
            value: Binding(get: { current }, set: { current = $0; seek(to: $0) }),
            in: 0...max(duration, 0.01),
            onEditingChanged: { scrubbing = $0 }
        )
        .tint(.orange)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            if loaded {
                // Frame stepping — the point of the app. Hold to run.
                HStack(spacing: 12) {
                    stepButton("backward.frame.fill", -1)
                    Button {
                        playing ? player.pause() : play()
                    } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .frame(width: 84, height: 66)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    stepButton("forward.frame.fill", 1)
                }

                // Only earns its row once you're zoomed — at 1x drag already scrubs.
                if zoom > 1 {
                    HStack(spacing: 8) {
                        Button { locked.toggle() } label: {
                            Label(L(locked ? "Locked" : "Lock area"),
                                  systemImage: locked ? "lock.fill" : "lock.open")
                                .frame(maxWidth: .infinity, minHeight: 34)
                        }
                        .tint(locked ? .orange : .primary)

                        Button(String(format: "%.1f× %@", zoom, L("reset"))) {
                            zoom = 1; zoomBase = 1; pan = .zero; panBase = .zero; locked = false
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .tint(.primary)
                    }
                    .font(.footnote.monospacedDigit().weight(.medium))
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 6) {
                    seekButton(-hugeSeek)
                    seekButton(-bigSeek)
                    seekButton(-smallSeek)
                    seekButton(smallSeek)
                    seekButton(bigSeek)
                    seekButton(hugeSeek)
                }

                tools
            } else {
                picker {
                    Label(L("Choose video"), systemImage: "film")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 46)
                }
                .buttonStyle(.bordered)
                .tint(.primary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 10)
        .padding(.top, loaded ? 8 : 14)
    }

    private var tools: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                tool("bookmark.fill", onMark ? .orange : .primary) { toggleMark() }
                tool("chevron.left.2", pois.isEmpty ? .secondary : .primary) { jump(-1) }
                tool("chevron.right.2", pois.isEmpty ? .secondary : .primary) { jump(1) }
                Button(loopLabel) { cycleLoop() }
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .tint(loopB != nil ? .orange : .primary)
            }
            HStack(spacing: 6) {
                Menu {
                    ForEach([0.1, 0.25, 0.5, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { s in
                        Button(rateLabel(s)) { speed = s; if playing { player.rate = Float(s) } }
                    }
                } label: {
                    Text(rateLabel(speed)).frame(maxWidth: .infinity, minHeight: 34)
                }
                .tint(speed == 1 ? .primary : .orange)

                tool("square.stack.3d.down.right.fill", onion ? .orange : .primary) { onion.toggle() }
                Button {
                    analyzing ? analyzeTask?.cancel() : detectHits()
                } label: {
                    Group {
                        if analyzing { Text("\(Int(analyzeProgress * 100))%") }
                        else if hits.isEmpty { Image(systemName: "waveform") }
                        else { Text(verbatim: "\(hits.count) \(L("hits"))") }
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .tint(hits.isEmpty ? .primary : .cyan)

                tool("square.and.arrow.up", .primary) { Task { await exportFrame() } }
            }
        }
        .font(.caption.monospacedDigit().weight(.medium))
        .lineLimit(1).minimumScaleFactor(0.7)
        .buttonStyle(.bordered)
    }

    private func tool(_ icon: String, _ tint: Color, _ act: @escaping () -> Void) -> some View {
        Button(action: act) {
            Image(systemName: icon).frame(maxWidth: .infinity, minHeight: 34)
        }
        .tint(tint)
    }

    private func rateLabel(_ s: Double) -> String {
        s == 1 ? "1×" : String(format: "%g×", s)
    }

    private var loopLabel: String {
        if loopB != nil { return L("A–B on") }
        return L(loopA == nil ? "Set A" : "Set B")
    }

    // MARK: - Marks, loop, hits

    private var pois: [Double] { (marks + hits).sorted() }
    private var onMark: Bool { MarkStore.index(near: current, in: marks, fps: fps) != nil }

    private func toggleMark() {
        marks = MarkStore.toggle(marks, at: current, fps: fps)
        saveMarks()
        if haptics { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    }

    /// Steps between marks and detected hits together — both are "a moment worth seeing".
    private func jump(_ dir: Int) {
        guard let target = MarkStore.next(after: current, in: pois, dir: dir, fps: fps) else { return }
        seek(to: target)
        if haptics { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    }

    private func cycleLoop() {
        if loopA == nil { loopA = current }
        else if loopB == nil { loopB = max(current, loopA! + 0.05) }
        else { loopA = nil; loopB = nil }
    }

    private func loadMarks() { marks = MarkStore.marks(for: clipID, in: marksStore) }

    private func saveMarks() { marksStore = MarkStore.setting(marks, for: clipID, in: marksStore) }

    // MARK: - Frames out

    private func scheduleGhosts() {
        ghostTask?.cancel()
        guard onion, !playing, loaded, let gen = generator else {
            if !ghosts.isEmpty { ghosts = [] }
            return
        }
        let base = current, gap = 1 / fps, n = max(1, Int(onionCount))
        ghostTask = Task {
            var out: [UIImage] = []
            for k in 1...n {
                let at = base - Double(k) * gap
                guard at >= 0, !Task.isCancelled,
                      let cg = try? await gen.image(at: CMTime(seconds: at,
                                                               preferredTimescale: 600)).image
                else { continue }
                out.append(UIImage(cgImage: cg))
            }
            if !Task.isCancelled { ghosts = out }
        }
    }

    private func exportFrame() async {
        guard let gen = generator else { return }
        let at = CMTime(seconds: current, preferredTimescale: 600)
        if let cg = try? await gen.image(at: at).image { shareImage = UIImage(cgImage: cg) }
    }

    private func detectHits() {
        guard let asset = player.currentItem?.asset else { return }
        analyzeTask?.cancel()
        analyzing = true; analyzeProgress = 0
        let sense = hitSense
        analyzeTask = Task { @MainActor in
            let found = (try? await Hits.find(in: asset, sensitivity: sense) { p in
                Task { @MainActor in analyzeProgress = p }
            }) ?? []
            guard !Task.isCancelled else { analyzing = false; return }
            hits = found
            analyzing = false
            if haptics { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        }
    }

    /// photoLibrary: .shared() so we get an identifier and can read the asset in place.
    private func picker<L: View>(@ViewBuilder _ label: () -> L) -> some View {
        PhotosPicker(selection: $pick, matching: .videos, photoLibrary: .shared(), label: label)
    }

    private func stepButton(_ icon: String, _ count: Int) -> some View {
        HoldButton(interval: 1 / max(holdRate, 1)) { step(count) } label: {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 66)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
        .keyboardShortcut(count < 0 ? .leftArrow : .rightArrow, modifiers: [])
    }

    private func seekButton(_ seconds: Double) -> some View {
        Button(Fmt.seek(seconds)) { seek(by: seconds) }
            .font(.caption.monospacedDigit().weight(.medium))
            .lineLimit(1).minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, minHeight: 34)
            .buttonStyle(.bordered)
            .tint(.secondary)
    }

    private func pinch(_ size: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { v in
                guard !locked else { return }
                zoom = min(max(zoomBase * v, 1), 8)
                pan = clamp(pan, size)
            }
            .onEnded { _ in zoomBase = zoom }
    }

    /// Zoomed and unlocked, dragging moves the frame. Locked (or at 1×) it scrubs frames —
    /// once the area is right you want to step through it, not nudge it off screen.
    private func drag(_ size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { g in
                if zoom > 1 && !locked {
                    pan = clamp(CGSize(width: panBase.width + g.translation.width,
                                       height: panBase.height + g.translation.height), size)
                } else {
                    let want = Int(g.translation.width / CGFloat(ptsPerFrame))
                    step(want - dragFrames)
                    dragFrames = want
                }
            }
            .onEnded { _ in panBase = pan; dragFrames = 0 }
    }

    // ponytail: clamps to the view box, not the letterboxed video, so you can pan slightly
    // into the black bars. Compute the real video rect if that ever annoys you.
    private func clamp(_ p: CGSize, _ size: CGSize) -> CGSize {
        let mx = size.width * (zoom - 1) / 2, my = size.height * (zoom - 1) / 2
        return CGSize(width: min(max(p.width, -mx), mx),
                      height: min(max(p.height, -my), my))
    }

    // MARK: - Transport

    private func step(_ count: Int) {
        guard count != 0, let item = player.currentItem else { return }
        if playing { player.pause() }
        guard count > 0 ? item.canStepForward : item.canStepBackward else { return }
        item.step(byCount: count)
        current = player.currentTime().seconds
        if haptics { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5) }
    }

    private func play() {
        if let a = loopA, let b = loopB, current >= b || current < a { seek(to: a) }
        else if current >= duration - 0.01 { seek(to: 0) }
        player.rate = Float(speed)
    }

    private func seek(by seconds: Double) {
        if playing { player.pause() }
        seek(to: player.currentTime().seconds + seconds)
    }

    private func seek(to seconds: Double) {
        let t = CMTime(seconds: max(0, min(seconds, duration)), preferredTimescale: 600)
        // Exact seek — default tolerance would land on a keyframe and lose the moment.
        player.seek(to: t, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    // MARK: - Setup

    private func start() {
        UIApplication.shared.isIdleTimerDisabled = keepAwake
        player.volume = Float(volume)
        // The racket contact sound is half the review; don't let the silent switch kill it.
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)

        guard observer == nil else { return }
        observer = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 60), queue: .main
        ) { t in
            if !scrubbing { current = t.seconds }
            // A–B: snap back at B so a rally repeats without touching anything.
            if let a = loopA, let b = loopB, rate != 0, t.seconds >= b { seek(to: a) }
        }
    }

    /// Ask at launch, not at pick time — granted access is what keeps us off the copy path.
    private func askPhotos() async {
        if PHPhotoLibrary.authorizationStatus(for: .readWrite) == .notDetermined {
            _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        // A previous request left running is the thing that made the next open never arrive.
        cancelLoad()

        // Clear the old clip first — leaving it up made a slow open look like nothing happened.
        player.pause()
        player.replaceCurrentItem(with: nil)
        loaded = false
        current = 0; duration = 0
        zoom = 1; zoomBase = 1; pan = .zero; panBase = .zero; locked = false
        analyzeTask?.cancel(); ghostTask?.cancel()
        hits = []; ghosts = []; loopA = nil; loopB = nil
        analyzing = false; generator = nil

        loading = true; problem = nil; progress = 0; elapsed = 0
        let ticker = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                elapsed += 1
            }
        }
        defer { ticker.cancel(); loading = false }
        do {
            let asset = try await open(item)
            // Show the first frame immediately; the readout can fill in a beat later.
            player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
            fps = 30
            loaded = true
            loading = false
            requestID = PHInvalidImageRequestID

            let gen = AVAssetImageGenerator(asset: asset)
            gen.appliesPreferredTrackTransform = true
            // Zero tolerance or the ghost frames are just the current frame again.
            gen.requestedTimeToleranceBefore = .zero
            gen.requestedTimeToleranceAfter = .zero
            gen.maximumSize = CGSize(width: 1280, height: 1280)
            generator = gen

            clipID = item.itemIdentifier ?? ""
            loadMarks()

            async let dur = asset.load(.duration)
            async let track = asset.loadTracks(withMediaType: .video).first
            duration = try await dur.seconds
            if let r = try await track?.load(.nominalFrameRate), r > 0 { fps = Double(r) }
        } catch {
            // 3072 is PHPhotosError.userCancelled — that's a choice, not a failure.
            let ns = error as NSError
            let cancelled = ns.domain == PHPhotosErrorDomain && ns.code == 3072
            problem = cancelled ? nil : error.localizedDescription
        }
    }

    /// Read the video straight out of the library. loadTransferable duplicates the whole
    /// file first, which on a multi-GB 240fps clip looks exactly like a hang.
    private func open(_ item: PhotosPickerItem) async throws -> AVAsset {
        await askPhotos()
        guard let id = item.itemIdentifier,
              let ph = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
            throw NSError(domain: "Koma", code: 1, userInfo: [NSLocalizedDescriptionKey:
                L("Allow Photos access in Settings — Koma reads videos in place instead of copying them.")])
        }
        return try await requestAsset(ph)
    }

    private func requestAsset(_ ph: PHAsset) async throws -> AVAsset {
        let opts = PHVideoRequestOptions()
        opts.isNetworkAccessAllowed = true          // it may still only exist in iCloud
        opts.deliveryMode = .highQualityFormat
        // .current makes iOS re-render any edit (slo-mo ramp, trim) before handing it over.
        // The original is both faster and what we actually want to step through.
        opts.version = .original
        opts.progressHandler = { p, _, _, _ in Task { @MainActor in progress = p } }
        // PHImageManager may call back more than once (degraded, then final); a checked
        // continuation traps on the second resume.
        var done = false
        return try await withCheckedThrowingContinuation { c in
            requestID = PHImageManager.default().requestAVAsset(forVideo: ph, options: opts) { asset, _, info in
                guard !done else { return }
                done = true
                if let asset { c.resume(returning: asset) }
                else {
                    c.resume(throwing: (info?[PHImageErrorKey] as? Error) ?? NSError(
                        domain: "Koma", code: 2,
                        userInfo: [NSLocalizedDescriptionKey: L("Couldn't read that video.")]))
                }
            }
        }
    }

}

#Preview { ContentView() }
