import Foundation

/// One recently opened clip and where I stopped watching it.
struct Recent: Codable, Identifiable, Equatable {
    let id: String          // Photos local identifier — same key marks use
    var at: Double          // seconds; where playback was left
    var duration: Double
    var openedAt: Double    // epoch seconds, for ordering
}

/// Recents as one JSON blob in UserDefaults, newest first.
/// ponytail: same trade as MarkStore — move both to SwiftData together, not separately.
enum HistoryStore {
    static let limit = 30

    static func decode(_ json: String) -> [Recent] {
        (try? JSONDecoder().decode([Recent].self, from: Data(json.utf8))) ?? []
    }

    static func encode(_ list: [Recent]) -> String {
        guard let d = try? JSONEncoder().encode(list) else { return "[]" }
        return String(decoding: d, as: UTF8.self)
    }

    static func position(for clip: String, in json: String) -> Double {
        decode(json).first { $0.id == clip }?.at ?? 0
    }

    /// Upsert, newest first, capped. An empty clip id is dropped — every unidentified
    /// video would otherwise share one row and overwrite each other's position.
    static func record(_ clip: String, at: Double, duration: Double,
                       openedAt: Double, in json: String) -> String {
        guard !clip.isEmpty else { return json }
        var list = decode(json).filter { $0.id != clip }
        list.insert(Recent(id: clip, at: at, duration: duration, openedAt: openedAt), at: 0)
        return encode(Array(list.prefix(limit)))
    }

    static func remove(_ clip: String, in json: String) -> String {
        encode(decode(json).filter { $0.id != clip })
    }
}
