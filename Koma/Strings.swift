import SwiftUI

// Two languages, ~40 strings. A .strings bundle per locale would mean two more files,
// a build-phase resource, and no in-app switch — iOS won't let an app override its
// own locale without a relaunch. A dictionary keyed by the English text does both.

enum Lang: String, CaseIterable {
    case en, vi
    static let key = "lang"
    var name: String { self == .en ? "English" : "Tiếng Việt" }
    static var current: Lang {
        Lang(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .en
    }
}

enum Skin: String, CaseIterable {
    case system, light, dark
    static let key = "appearance"
    var scheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
    var name: String {
        switch self {
        case .system: return L("System")
        case .light:  return L("Light")
        case .dark:   return L("Dark")
        }
    }
    static var current: Skin {
        Skin(rawValue: UserDefaults.standard.string(forKey: key) ?? "") ?? .dark
    }
}

/// English text in, displayed text out. Missing translation falls back to English,
/// which is the right failure: readable, not a "MISSING_KEY" in someone's face.
func L(_ en: String) -> String {
    Lang.current == .vi ? vietnamese[en] ?? en : en
}

private let vietnamese: [String: String] = [
    // Loading / empty
    "Opening…": "Đang mở…",
    "Cancel": "Huỷ",
    "Load a rally": "Mở một pha cầu",
    "Record at 120 or 240fps — more frames per swing.":
        "Quay ở 120 hoặc 240fps — nhiều khung hình hơn cho mỗi cú vung.",
    "Choose video": "Chọn video",
    "Allow Photos access in Settings — Koma reads videos in place instead of copying them.":
        "Cho phép truy cập Ảnh trong Cài đặt — Koma đọc video tại chỗ thay vì sao chép.",
    "Couldn't read that video.": "Không đọc được video đó.",

    // Controls
    "Close video": "Đóng video",
    "Play hits only": "Chỉ phát pha có cú đánh",
    "Locked": "Đã khoá",
    "Lock area": "Khoá vùng",
    "reset": "đặt lại",
    "Set A": "Đặt A",
    "Set B": "Đặt B",
    "A–B on": "A–B bật",
    "hits": "cú đánh",

    // History
    "Recent": "Gần đây",
    "Nothing opened yet.": "Chưa mở clip nào.",
    "See all": "Xem tất cả",
    "History": "Lịch sử",
    "Every clip you open is listed here with where you stopped. Tap one to reopen it at that frame; swipe to remove it.":
        "Mọi clip đã mở đều nằm ở đây kèm chỗ đã xem tới. Chạm để mở lại đúng khung đó; vuốt để xoá.",

    // Hits-only video
    "Hits-only video": "Video chỉ có cú đánh",
    "Find hits again": "Dò lại cú đánh",
    "Clear hits": "Xoá các cú đánh",
    "Before each hit": "Trước mỗi cú đánh",
    "After each hit": "Sau mỗi cú đánh",
    "How much of the clip to keep around each hit. Windows that overlap are joined, so a fast exchange stays in one piece.":
        "Giữ lại bao nhiêu quanh mỗi cú đánh. Các đoạn chồng nhau sẽ được nối lại, nên một pha giao tranh nhanh vẫn liền mạch.",
    "That clip has no video track.": "Clip này không có luồng video.",
    "Couldn't start the export.": "Không khởi động được việc xuất video.",
    "Export failed.": "Xuất video thất bại.",
    "Cuts every detected hit into one new clip, back to back — a 20-minute session becomes the shots only. Length of each piece is in Settings.":
        "Cắt mọi cú đánh đã dò được thành một clip mới, nối liên tiếp — buổi tập 20 phút chỉ còn các cú đánh. Độ dài mỗi đoạn chỉnh trong Cài đặt.",

    // Settings
    "Settings": "Cài đặt",
    "Done": "Xong",
    "Stepping": "Bước khung hình",
    "Drag sensitivity": "Độ nhạy khi kéo",
    "Hold speed": "Tốc độ khi giữ",
    "Drag across the video to scrub. Hold a step button to run.":
        "Kéo ngang video để tua. Giữ nút bước để chạy liên tục.",
    "Skip buttons": "Nút nhảy",
    "Small skip": "Nhảy ngắn",
    "Large skip": "Nhảy vừa",
    "Huge skip": "Nhảy dài",
    "Analysis": "Phân tích",
    "Onion skin frames": "Số khung bóng mờ",
    "Hit sensitivity": "Độ nhạy nhận cú đánh",
    "Lower sensitivity finds more hits and more false ones. Tune it on real court footage — hall noise differs everywhere.":
        "Độ nhạy thấp bắt được nhiều cú hơn nhưng cũng nhiều cú sai hơn. Chỉnh trên video sân thật — tiếng ồn mỗi nhà thi đấu mỗi khác.",
    "Playback": "Phát",
    "Volume": "Âm lượng",
    "Tap the speaker to mute. The exact level is in Settings — the hit sound is what you are listening for.":
        "Chạm loa để tắt tiếng. Chỉnh mức cụ thể trong Cài đặt — tiếng chạm cầu là thứ cần nghe.",
    "Haptic on each frame": "Rung mỗi khung hình",
    "Keep screen awake": "Giữ màn hình sáng",
    "Reset to defaults": "Đặt lại mặc định",
    "Appearance": "Giao diện",
    "Language": "Ngôn ngữ",
    "System": "Theo hệ thống",
    "Light": "Sáng",
    "Dark": "Tối",

    // Help
    "What the buttons do": "Các nút dùng để làm gì",
    "Step back / forward": "Lùi / tiến một khung",
    "One exact frame. Hold to run frames continuously. This is the whole point of the app.":
        "Đúng một khung hình. Giữ để chạy liên tục. Đây là chức năng chính của app.",
    "Play / pause": "Phát / tạm dừng",
    "Plays at the speed you picked, inside the A–B loop if one is set.":
        "Phát ở tốc độ đã chọn, trong vòng lặp A–B nếu có đặt.",
    "Skip by seconds or minutes": "Nhảy theo giây hoặc phút",
    "Lands on the exact time, not the nearest keyframe. Sizes are in Settings.":
        "Nhảy đúng mốc thời gian, không phải keyframe gần nhất. Chỉnh độ dài trong Cài đặt.",
    "Mark": "Đánh dấu",
    "Bookmark this frame. Orange means already marked. Saved per clip.":
        "Đánh dấu khung này. Màu cam là đã đánh dấu. Lưu riêng theo từng clip.",
    "Jump to mark or hit": "Nhảy tới dấu hoặc cú đánh",
    "Previous or next mark or detected hit.": "Dấu hoặc cú đánh trước / kế tiếp.",
    "A–B loop": "Vòng lặp A–B",
    "Tap to set A, tap again to set B, once more to clear. Playback loops A→B.":
        "Chạm để đặt A, chạm nữa đặt B, chạm lần ba để xoá. Phát lặp A→B.",
    "Speed": "Tốc độ",
    "0.1× to 2×. Slow to read the swing, fast to skip between rallies.":
        "0.1× đến 2×. Chậm để xem cú vung, nhanh để lướt qua giữa các pha.",
    "Onion skin": "Bóng mờ (onion skin)",
    "Shows the frames before this one as faded ghosts, so the whole swing path is in one picture.":
        "Hiện các khung trước đó dưới dạng bóng mờ, thấy nguyên đường vung trong một ảnh.",
    "Find hits": "Tìm cú đánh",
    "Listens for the racket-on-shuttle crack and marks those frames in cyan. Tap again while running to cancel. Sensitivity is in Settings.":
        "Nghe tiếng vợt chạm cầu và đánh dấu các khung đó màu xanh lam. Chạm lại khi đang chạy để huỷ. Độ nhạy trong Cài đặt.",
    "Export frame": "Xuất khung hình",
    "Shares the current frame as an image.": "Chia sẻ khung hình hiện tại dưới dạng ảnh.",
    "Zoom": "Phóng to",
    "Pinch to zoom, drag to move. Buttons appear once you're zoomed in.":
        "Chụm hai ngón để phóng, kéo để di chuyển. Nút hiện ra khi đã phóng to.",
    "Freezes the zoom so dragging scrubs time instead of moving the picture.":
        "Khoá vùng phóng, để kéo là tua thời gian chứ không xê dịch hình.",
    "Ignore voices": "Bỏ qua tiếng người",
    "Voice confidence": "Độ tin tiếng người",
    "Ignore voices runs a second pass that drops hits landing on speech or laughter. It can also drop a real hit if someone shouts during the rally — raise the confidence if that happens.":
        "Bỏ qua tiếng người chạy thêm một lượt nữa, loại các cú đánh rơi vào tiếng nói hay tiếng cười. Nó cũng có thể loại nhầm cú đánh thật nếu có người hét trong pha cầu — khi đó tăng độ tin lên.",
    "Skeleton": "Khung xương",
    "Draws the body joints on the frozen frame — shoulder, elbow, wrist at the moment of contact. Hold it to keep drawing while the video plays (orange), which lags a little.":
        "Vẽ các khớp lên khung hình đang dừng — vai, khuỷu, cổ tay ngay lúc chạm cầu. Nhấn giữ để vẽ cả khi video đang phát (màu cam), hơi trễ một chút.",
    "Skeleton while playing": "Khung xương khi đang phát",
    "The skeleton normally draws only on a paused frame. Turned on, it also draws while the video runs — but it lags the picture and updates a few times a second, because finding the joints takes longer than a frame.":
        "Bình thường khung xương chỉ vẽ trên khung hình đang dừng. Bật lên thì vẽ cả khi video đang chạy — nhưng nó trễ so với hình và mỗi giây chỉ cập nhật vài lần, vì tìm khớp mất nhiều thời gian hơn một khung hình.",
]
