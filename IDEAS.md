# App Ideas — SwiftUI + Local Database

Pick one by ID. All are offline-first, SwiftData (or SQLite) backed, single-user, no server.

| ID | Name | Core iOS API | Difficulty |
|----|------|--------------|------------|
| A1 | Regret Log | Notifications, date math | ★☆☆ |
| A2 | Ghost Places | CoreLocation background | ★★★ |
| A3 | Sound Diary | AVAudioEngine, BGTask | ★★★ |
| A4 | Lie Ledger | LocalAuthentication | ★☆☆ |
| A5 | Dead Man's App | Keychain, notifications | ★★☆ |
| A6 | Object Debt | VisionKit, Charts | ★★☆ |
| A7 | Argument Replay | Scheduled reveal | ★☆☆ |
| B1 | Battery Biography | Battery/state monitoring | ★★☆ |
| B2 | Nobody's Photos | PhotoKit, Vision | ★★☆ |
| B3 | Time Debt Bank | Screen Time / manual ledger | ★★☆ |
| B4 | Reverse Alarm | HealthKit sleep, notifications | ★★☆ |
| B5 | The Unsent Box | SwiftData + drafts, no send | ★☆☆ |
| B6 | Room Tone Match | AVAudio FFT, similarity search | ★★★ |
| B7 | Contact Half-Life | Contacts, CallKit-adjacent logs | ★★☆ |
| B8 | Proof of Boredom | Motion sensors, timer | ★★☆ |
| **C1** | **Frame Step (badminton)** — my real problem | AVFoundation frame stepping | ★★☆ | ← **chosen** |

---

## A1 — Regret Log
Write down a decision **before** knowing the outcome. Entry is locked. App pings you in 30/90 days to rate how it actually went. Over a year you see whether your gut is trustworthy.

- `Decision(text, madeAt, reviewAt, confidence)`
- `Outcome(decisionID, rating, note, ratedAt)`
- Learn: SwiftData, `UNUserNotificationCenter`, immutable records.

## A2 — Ghost Places
Passively records where you stood still >5 minutes. No pins, no place names — only a heatmap of your ghost. "40 hours this year at a spot you never chose."

- `Stay(lat, lon, start, end)`
- Learn: CoreLocation significant-change, background modes, Charts, clustering.

## A3 — Sound Diary
Records 3 seconds of ambient audio every hour. No player UI — a wall of waveforms for the year. Tap = hear one random second.

- `Clip(path, recordedAt, loudness)`
- Learn: AVAudioEngine, file storage + DB refs, BGTaskScheduler, privacy prompts.

## A4 — Lie Ledger
Log small lies. App asks only "who" and "why". Weekly it shows who you lie to most. Face ID locked, never leaves device.

- `Person(name)` / `Lie(personID, reason, at)`
- Learn: LocalAuthentication, relationships, group-by aggregation.

## A5 — Dead Man's App
Check in daily. Miss N days → the app reveals notes you pre-wrote. Local-only deadman switch.

- `Note(body, unlockAfterDays, revealed)` / `Checkin(at)`
- Learn: notifications, Keychain-encrypted fields, state machines.

## A6 — Object Debt
Scan an object, enter price + expected uses. Tap once each time you use it. Watch cost-per-use fall. Kills impulse buying.

- `Item(name, price, photo, boughtAt)` / `Use(itemID, at)`
- Learn: VisionKit scanner, image storage, computed/derived queries, Charts.

## A7 — Argument Replay
Two columns, log both sides live during an argument. Seven days later the app shows you **only the other side's** column.

- `Argument(withWhom, at)` / `Line(argumentID, side, text)`
- Learn: split layout, time-gated queries, SwiftData predicates.

---

# Better / stranger ideas

## B1 — Battery Biography
Your phone's battery curve as an autobiography. Records charge level every few minutes and lets you annotate *shapes*, not times: "this cliff was the interview", "this flat line was the hospital". Life told as a discharge graph.

- `Sample(level, state, at)` / `Chapter(startAt, endAt, title, note)`
- Learn: `UIDevice.batteryLevel` + notifications, BGTask sampling, Charts with selection, range-annotation UI.
- Why good: real time-series DB work, zero permissions friction, visually striking.

## B2 — Nobody's Photos
Scans your photo library for pictures with **no faces, no text, no landmarks** — the accidental shots, the pocket photos, the blurry ground. Builds an archive of everything you never meant to keep. Rate them; keeps the best "accidents".

- `Candidate(assetID, faceCount, hasText, blurScore, keptAt, rating)`
- Learn: PhotoKit fetching, Vision requests (face/text/quality), batch background indexing, incremental sync into DB.
- Why good: teaches the hard part of real apps — indexing an external data source into your own DB and keeping it in sync.

## B3 — Time Debt Bank
You borrow time from your future self, with interest. "Watching 1 more hour → owe 1h15m." The debt sits there. Pay it back with logged focused work. Balance can go deeply, hilariously negative.

- `Loan(minutes, reason, at, interestRate)` / `Repayment(minutes, at)` / derived `balance`
- Learn: money-style math (never floats), ledger schema, running-balance queries, a real invariant to unit-test.
- Why good: the only idea here with logic worth testing properly.

## B4 — Reverse Alarm
Not "wake me at 7". It's "you must be asleep by X or the app records the failure". Tracks the gap between intended and actual sleep, and shows the drift line over months. Punishment-free, just an honest graph of your decay.

- `Intent(bedtimeTarget, forDate)` / `Actual(sleepStart, source)`
- Learn: HealthKit sleep reads, permissions, notification scheduling, joining two datasets by day.

## B5 — The Unsent Box
A messaging app with **no send button**. Pick a real contact, write the message, and it sits there forever. Shows you a thread of everything you almost said to each person. Optional: after 1 year, it offers to send.

- `Recipient(contactID, name)` / `Draft(recipientID, body, writtenAt)`
- Learn: Contacts framework, chat-style SwiftUI list, per-recipient queries. Easiest build here; strongest emotional hook.

## B6 — Room Tone Match
Every room has a sound fingerprint. Record 10s of "nothing" in a room, store its frequency signature. Later, record anywhere and the app tells you which saved room it sounds most like — including rooms you can't identify anymore.

- `Room(name, signature: [Float], recordedAt)` / `Probe(signature, matchedRoomID, distance, at)`
- Learn: AVAudioEngine tap, Accelerate/vDSP FFT, storing vectors in a DB, nearest-neighbour search.
- Hardest, most impressive. Signature comparison needs a real tuning threshold — leave it adjustable.

## B7 — Contact Half-Life
Each person in your contacts decays. Log an interaction → they reset to full. Do nothing → they fade toward zero over their own half-life (you set it: some friends are fine at yearly). Home screen is a list of people quietly dying out.

- `Person(contactID, halfLifeDays)` / `Touch(personID, kind, at)` / computed `strength = 0.5^(daysSince/halfLife)`
- Learn: Contacts import, exponential decay math, sorting by computed values, widgets.

## B8 — Proof of Boredom
Start a session and the app watches the accelerometer. Any pickup, any tilt, any tap = failure. It certifies, with a signed record, how long you did *absolutely nothing*. Leaderboard against your own past self only.

- `Session(start, end, failedAt, reasonForFailure)` 
- Learn: CoreMotion, sensor thresholds (needs real-world calibration, not paper values), screen-idle handling, streak queries.

---

## Recommendation

- **Ship in a weekend:** B5 or A1
- **Best learning-per-hour:** B1 (time-series + Charts) or A6
- **Hardest, most bragging rights:** B6
- **Most code worth testing:** B3

Reply with an ID.

---

# C — My own problem

## C1 — Frame Step (badminton video review) ✅ CHOSEN / BUILT

**Problem:** Badminton is too fast. When I record and rewatch a rally, the racket
hit happens between frames of normal playback — I can't tell what actually
happened at the moment of contact. Every normal video player only lets me scrub
by seconds, which is far too coarse for a shuttle at 300+ km/h.

**What the app must do:**
- **Main feature:** step forward/backward exactly **one frame** at a time.
- Bonus: step by 1 second.
- Bonus: step by 1 minute.
- Play/pause. Load a video from my own library.

**Approach:** `AVPlayerItem.step(byCount:)` — iOS does exact frame stepping
natively, so no frame-extraction pipeline is needed. Seeks use zero tolerance so
±1s lands on the exact time instead of the nearest keyframe. Custom
`AVPlayerLayer` instead of AVKit's `VideoPlayer`, whose built-in controls fight
with stepping.

**Note:** record in 120/240fps slo-mo — more frames per second of real time means
each step reveals more of the swing.

- Data: none yet (no database). Add `Clip(url, importedAt)` + `Mark(clipID, time, note)`
  when I want to bookmark contact moments across sessions.
- App name: **Koma** (駒 — a single frame of film). Icon: `icon.svg`.
- File: `Koma/ContentView.swift`
- Build: `./make-ipa.sh` → `build/Koma.ipa`, drag into Sideloadly.
- Status: running on simulator and on my iPhone 11 (iOS 26.3) over WiFi.

**Built on top of frame stepping:**
1. **Hit detection** — the racket sound is a sharp transient, so the audio finds
   contact moments the eye can't. Cyan ticks on the timeline, jump straight to them.
2. **Marks + jump** — bookmark a frame, jump prev/next. Saved per clip.
3. **Onion skin** — previous frames as faded ghosts, so the swing path is visible
   in one still image.
4. **A–B loop + slow speed** — loop just the rally, at 1/8x.
5. **Export frame** — share the exact frame as a PNG.
6. Drawing on a frozen frame — see C1-d below. Not built, still discussing.
7. **History + resume** — the next problem: I open the same rally over and over,
   and every time I have to find it in the picker again and scrub back to where I
   stopped. So: a list of recently opened clips, and each one remembers the frame
   I left off at.
   - Data: `Recent(clipID, lastTime, duration, openedAt)`, keyed by the Photos
     local identifier like marks are. JSON blob in UserDefaults for now.

Files: `Koma/ContentView.swift` (screen), `Config.swift` (knobs + formatting),
`Marks.swift`, `History.swift`, `Hits.swift` (pure logic, unit tested),
`SettingsView.swift`, `HelpView.swift`, `HistoryView.swift`, `Strings.swift` (en/vi).

---

## C1 — Not built yet

Problems first, code later. Ordered by value ÷ effort — a–c all stand on the hit
detection that already exists, so together they are less code than e alone.

| ID | Feature | Cost | Depends on |
|----|---------|------|-----------|
| C1-h | **Hits-only video** — built | ★★☆ | hit detection |
| C1-i | Voice veto (Apple sound classifier) ← building now | ★☆☆ | hit detection |
| C1-j | Spectral + decay filter | ★☆☆ | hit detection |
| C1-k | Custom Create ML sound classifier | ★★☆ | C1-i |
| C1-l | Shuttle trajectory detection (Vision) | ★★★ | — |
| C1-m | Shuttle tracking (tap to track) | ★★☆ | — |
| C1-n | Skeleton while playing ← building now | ★☆☆ | skeleton |
| C1-a | Auto-slow at each hit | ★☆☆ | hit detection |
| C1-b | Contact sheet | ★☆☆ | frame export |
| C1-c | Rally list | ★☆☆ | hit detection |
| C1-d | Drawing on a frame | ★★☆ | frame export |
| C1-e | Mark labels | ★★☆ | marks |
| C1-f | Side-by-side compare | ★★★ | — |
| C1-g | Trim and save back | ★★☆ | — |

### C1-h — Hits-only video ← building now
**Problem:** a 20-minute clip is maybe 90 seconds of actual shots. Everything else
is walking, picking up shuttles, and talking. Rewatching means scrubbing past all
of it, every time.
**Do:** reuse the detected hits — cut a new video containing only a window around
each one, back to back. Overlapping windows merge into one longer piece, so a fast
exchange stays continuous instead of stuttering. Share or save the result.
- Before/after the hit are knobs. 0.5s / 1.0s is a starting guess; a smash needs
  less lead-in than a serve.
- `Reel.ranges` is pure and unit tested. The export is AVMutableComposition +
  AVAssetExportSession — no frame re-encoding logic of my own.

### C1-i — Voice veto ← building now
**Problem:** `Hits.pick` only measures how far the amplitude jumps above the recent
background. A laugh, a shout, someone calling the score — all of them jump the same
way a racket does. Peak amplitude throws away frequency, which is the one thing that
actually separates them.
**Do:** keep the existing detector exactly as it is, and add a second pass that
*removes* candidates. `SNClassifySoundRequest` (SoundAnalysis, on-device, built into
iOS, no training) classifies ~300 sounds including speech, laughter, shouting. It has
no label for a racket hit, so it is useless for finding — but good at vetoing.
- A toggle, because it can be wrong in the expensive direction: someone shouting
  *during* a rally could delete a real hit. Confidence threshold is a knob.
- Needs a file-backed asset; PhotoKit normally hands back an `AVURLAsset`. If it
  does not, skip the filter rather than fail the detection.

### C1-j — Spectral + decay filter
**Problem:** same as C1-i, from the signal side rather than the model side.
**Do:** a racket hit is broadband with most energy above 5kHz, rises in under 5ms and
is gone in ~40ms. Speech sits under 4kHz, rises slowly and sustains past 200ms. So:
run the envelope a second time over the first-order difference of the samples (a crude
high-pass) and require a high ratio; then require the energy to fall to a third within
~50ms of the peak. Cheaper than C1-i and it thins the candidates before any model runs.
- Note the current window is 12ms — longer than the hit itself, which is why the
  attack shape is invisible today. This wants a shorter window.

### C1-k — Custom Create ML sound classifier
**Problem:** no general model has a "badminton racket hit" class, because nobody
trained one on my gym, my racket, my phone's mic.
**Do:** label ~100 one-second "hit" clips and ~200 "not hit" (talking, laughing,
shuttle landing, shoe squeak) out of my own footage, train in Create ML (ships with
Xcode), export a ~1–5MB `.mlmodel`, run it through the same `SNClassifySoundRequest`
path C1-i builds. Best accuracy available here. The cost is entirely labelling — one
evening — and the app itself is the labelling tool.

### C1-l — Shuttle trajectory detection (Vision)
**Problem:** in a loud hall the audio may simply not be separable.
**Do:** `VNDetectTrajectoriesRequest` — Apple built it for ball sports. A sudden
direction change is a contact. Immune to noise, and it yields direction and speed, not
just a timestamp. Needs a still camera on a tripod, and the shuttle is small and
motion-blurred — though 120/240fps is the best case for it. A separate feature, not a
patch to the audio path.


**Measured on IMG_4382.MOV (14:36, 1080p60, handheld, ~1.9GB) — result: does not work.**
- `VNDetectTrajectoriesRequest` needs a **CMSampleBuffer**, not a CVPixelBuffer: with a
  bare pixel buffer it has no timestamps and silently returns zero results, no error.
- It does detect *something*: ~300 trajectories per 20s. But after filtering to long
  travels and looking for direction reversals, the reversal times agree with the audio
  candidates **at or below chance** (40s window: 22 vision events, 8 matched audio
  within ±0.3s, chance expectation 10.9). Tightening the travel cut, the radius bounds
  and the confidence only thins both sides — agreement never beats chance.
- Reading: it is tracking limbs, shirts and background flicker, not the shuttle. The
  shuttle at this distance is a few pixels, motion-blurred at 60fps, and the camera moves.
- Verdict: **not worth building** without a tripod and a much closer/faster camera.
  Revisit only with 240fps on a fixed mount.

### C1-m — Shuttle tracking (tap to track)
**Problem:** C1-l failed because `VNDetectTrajectoriesRequest` has to *find* the shuttle
itself, and at this distance it is a few blurred pixels — it locked onto limbs and shirts.
**Do:** don't make it search. Drag a box over the shuttle on one frame, then
`VNTrackObjectRequest` + `VNSequenceRequestHandler` carries that box forward frame by
frame. Draw the path it walks. Same Vision framework, but the hard half — detection — is
done by hand, once.
**Risk:** the tracker is built for objects that keep their appearance. A shuttle changes
shape, blurs, and crosses a busy background. Expect it to drift off after a handful of
frames. **Bench it against the video before writing any UI** — that is the whole lesson
of C1-l.

**Measured on IMG_4382.MOV, rally at ~121s — result: does not work, for two reasons.**
- **There is nothing to tap.** At full 1080p and again at 2.2× zoom over mid-court and
  over the net band, at six timestamps through a live rally, the shuttle is not visible
  at all. A three-frame brightness differencer (bright in frame N, absent in N−1 and N+1,
  blobs capped at 400px) over the whole court finds exactly one small fast bright object
  and it is the **racket head**, not the shuttle. If I cannot find it in a still at 2.2×,
  the user cannot drag a box over it on a phone.
- **The tracker drifts and lies about it.** Seeded on the racket head (26×20px, conf 1.0),
  `VNTrackObjectRequest` at `.accurate` slid off within ~12 frames and then sat frozen at
  (656,1034) for six straight frames — parked on a court line — while reporting
  **confidence 0.68–0.78 the whole time**. Confidence never dropped, so there is no
  threshold that detects the failure. A silent wrong answer is worse than no answer.
- Verdict: **not worth building.** Same root cause as C1-l — the shuttle is a few blurred
  pixels at this camera distance. Revisit only with the camera much closer or at 240fps.

### C1-n — Skeleton while playing ← building now
**Problem:** the skeleton only draws on a paused frame. Watching a swing at 0.25× I
still see no joints, which is exactly when I want them.
**Do:** an opt-in toggle, off by default. Added, not replacing — paused behaviour is
untouched. Vision costs ~27ms a frame and the video runs at 60fps, so it cannot keep up;
the honest design is to let one pass finish and skip every frame that arrives meanwhile,
rather than cancel each pass before it completes and draw nothing at all. The skeleton
lags the picture and updates a few times a second. Whoever turns it on is accepting that.
**Not doing:** precomputing a window around the playhead into a cache. More code, more
memory, and a wait before playback starts — revisit only if the lag is unusable.

### C1-a — Auto-slow at each hit
**Problem:** to watch a rally properly I have to keep changing speed by hand —
1× between shots, 0.25× at the contact. So I either miss the contact or crawl
through the whole clip.
**Do:** playing at 1×, drop to 0.25× starting ~0.5s before each detected hit and
restore afterwards. One toggle, no other input. Off by default; the slow window
and the slow speed both need to be knobs (a smash and a drop need different ones).

### C1-b — Contact sheet
**Problem:** one exported frame does not show a swing. To show someone what my
arm did I have to send five separate screenshots.
**Do:** export N consecutive frames around a chosen time as a single strip image,
frame numbers burned in. N and the spacing (every frame? every 3rd?) are knobs.

### C1-c — Rally list
**Problem:** a 20-minute clip is mostly walking, picking up shuttles, and talking.
Finding the fourth rally means scrubbing.
**Do:** cluster the detected hits — hits close together are one rally, a long gap
is a break. Show "Rally 1 · 0:12 · 8 shots" and jump straight there. The gap that
splits two rallies is a knob; it differs between a match and a drill.

### C1-d — Drawing on a frame
**Problem:** I can see the racket angle is wrong but cannot point at it.
**Do:** freeze a frame, draw on it, export. Open question I still owe an answer
to: just for me (freehand, erase-all, nothing saved) or to send to someone
(saved per mark, undo, arrows and angle lines)? The second is ~3× the first.

### C1-e — Mark labels
**Problem:** all marks look the same, so I cannot ask for "only the smashes".
**Do:** a type on each mark (smash / drop / clear / error) and jump filtered by
type. Cheap in code; the cost is the typing, which is unpleasant mid-review —
a fixed set of tap-to-pick labels, never free text.

### C1-f — Side-by-side compare
**Problem:** my swing versus a reference swing, stepped together, is the fastest
way to see the difference.
**Do:** two players, two timelines, linked stepping with an adjustable offset so
the two contacts line up. Highest learning value here, and by far the most code —
two of every piece of state, on an iPhone 11 screen.

### C1-g — Trim and save back to Photos
**Problem:** sending a whole 20-minute clip to share one rally.
**Do:** export A–B as a new video. Low priority — Photos already trims, this only
earns its place if C1-c makes rallies one tap away.
