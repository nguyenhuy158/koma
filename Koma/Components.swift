import SwiftUI
import AVFoundation

/// Tap steps once, hold runs. Tapping 30 times to cross a swing is the real pain.
struct HoldButton<L: View>: View {
    var interval: TimeInterval = 0.05
    let action: () -> Void
    @ViewBuilder let label: () -> L
    @StateObject private var repeater = Repeater()

    var body: some View {
        Button(action: action, label: label)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in repeater.arm(every: interval, action) }
                    .onEnded { _ in repeater.stop() }
            )
    }

    final class Repeater: ObservableObject {
        private var timer: Timer?
        /// Wait out a normal tap (the Button already handles that), then run.
        func arm(every interval: TimeInterval, _ action: @escaping () -> Void) {
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                self?.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
                    action()
                }
            }
        }
        func stop() { timer?.invalidate(); timer = nil }
    }
}

/// AVKit's VideoPlayer brings its own controls that fight with frame stepping.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> LayerView {
        let v = LayerView()
        v.backgroundColor = .black
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspect
        return v
    }

    func updateUIView(_ uiView: LayerView, context: Context) {}

    final class LayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// The share sheet. ShareLink would need a Transferable wrapper for one UIImage.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
