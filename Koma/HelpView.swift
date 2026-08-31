import SwiftUI

/// Every gesture in this app is invisible — a sheet is cheaper than onboarding.
struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    private let gestures: [(String, String, String)] = [
        ("hand.draw", "Drag on the video", "Scrub. At 1× it scrubs, when zoomed it pans."),
        ("magnifyingglass", "Pinch", "Zoom in on the shuttle or the racket face."),
        ("lock.fill", "Lock area", "Freezes the zoom box so dragging scrubs again instead of panning."),
    ]

    private let controls: [(String, String, String)] = [
        ("forward.frame.fill", "Frame step", "One exact frame per tap. Hold to run at the rate set in Settings."),
        ("plus.forward.arrow", "Skip buttons", "Three tiers each way — all three are configurable in Settings."),
        ("bookmark.fill", "Mark", "Bookmark the current frame. Saved per video."),
        ("chevron.right.2", "Jump", "Next / previous mark or detected hit."),
        ("repeat", "A–B loop", "Tap once to set A, again for B, again to clear."),
        ("square.stack.3d.down.right.fill", "Onion skin", "Ghosts of the previous frames over the current one — shows the swing path."),
        ("figure.badminton", "Skeleton", "Draws the body joints on the frozen frame — shoulder, elbow, wrist at the moment of contact. Hold it to keep drawing while the video plays (orange), which lags a little."),
        ("waveform", "Find hits", "Scans the audio for racket contacts and drops a jump point on each."),
        ("film.stack", "Hits-only video",
         "Cuts every detected hit into one new clip, back to back — a 20-minute session becomes the shots only. Length of each piece is in Settings."),
        ("clock.arrow.circlepath", "History",
         "Every clip you open is listed here with where you stopped. Tap one to reopen it at that frame; swipe to remove it."),
        ("speaker.wave.2.fill", "Volume",
         "Tap the speaker to mute. The exact level is in Settings — the hit sound is what you are listening for."),
        ("square.and.arrow.up", "Export frame", "Shares the current frame as a still image."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Gestures") { ForEach(gestures, id: \.1, content: row) }
                Section("Controls") { ForEach(controls, id: \.1, content: row) }
                Section {
                    Text("Frame stepping is only as fine as the footage. Record at 120 or 240 fps and every tap is a quarter of the motion.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("How to use")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ item: (String, String, String)) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.1).font(.subheadline.weight(.medium))
                Text(item.2).font(.caption).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: item.0).foregroundStyle(.orange).frame(width: 24)
        }
    }
}
