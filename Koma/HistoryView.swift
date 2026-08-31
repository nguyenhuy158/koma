import SwiftUI
import Photos

/// Recently opened clips, each with where playback stopped. Tapping one reopens it —
/// the Photos picker makes you hunt for the same rally every single time.
struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Store.history) private var history = "[]"
    @AppStorage(Lang.key) private var lang = Lang.en.rawValue
    let onPick: (String) -> Void

    var body: some View {
        NavigationStack {
            Group {
                let items = HistoryStore.decode(history)
                if items.isEmpty {
                    Text(L("Nothing opened yet."))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(items) { r in
                            Button { onPick(r.id); dismiss() } label: { row(r) }
                                .tint(.primary)
                        }
                        .onDelete { idx in
                            for i in idx { history = HistoryStore.remove(items[i].id, in: history) }
                        }
                    }
                }
            }
            .navigationTitle(L("Recent"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button(L("Done")) { dismiss() } }
        }
    }

    private func row(_ r: Recent) -> some View {
        HStack(spacing: 12) {
            Thumb(id: r.id)
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.when(r.openedAt)).font(.subheadline.weight(.medium))
                Text(verbatim: "\(Fmt.timecode(r.at)) / \(Fmt.timecode(r.duration))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if r.duration > 0 {
                    ProgressView(value: min(r.at / r.duration, 1)).tint(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private static func when(_ epoch: Double) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: Date(timeIntervalSince1970: epoch))
    }
}

/// Loads its own thumbnail. Cheap: PhotoKit caches these, and the list is 30 rows max.
private struct Thumb: View {
    let id: String
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.25)
            }
        }
        .frame(width: 64, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            guard image == nil,
                  let a = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
            else { return }
            let opts = PHImageRequestOptions()
            opts.isNetworkAccessAllowed = true
            opts.deliveryMode = .opportunistic
            PHImageManager.default().requestImage(
                for: a, targetSize: CGSize(width: 192, height: 132),
                contentMode: .aspectFill, options: opts
            ) { img, _ in if let img { image = img } }
        }
    }
}
