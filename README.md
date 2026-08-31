# Koma

Frame-by-frame video player for reviewing badminton footage. The problem it
solves is C1 in [IDEAS.md](IDEAS.md): the racket-shuttle contact happens
between frames of normal playback.

Step **one frame** forward/back (the point of the app), plus ±1s and ±1m.
Drag on the video to scrub by frames. Record in 120/240fps slo-mo so each
step reveals more of the swing.

## Build

    open Koma.xcodeproj                                  # simulator: Cmd-R
    xcodebuild -scheme Koma -sdk iphonesimulator build

## Install on a real device

Xcode 15.4 (macOS 14.7.6) can't install to an iPhone on iOS 26.3, so
Sideloadly does it with a free Apple ID:

    ./make-ipa.sh          # -> build/Koma.ipa

Drag that .ipa into Sideloadly. Signature expires after 7 days — re-sign then.
