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
6. Drawing on a frozen frame — not built yet, still discussing.
