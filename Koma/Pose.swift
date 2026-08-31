import AVFoundation
import UIKit
import Vision

/// Body joints drawn over the frozen frame — where the shoulder, elbow and wrist actually
/// were at contact, which is the thing you cannot see by staring at a blurred arm.
enum Pose {
    private static let bones: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .nose), (.neck, .rightShoulder), (.neck, .leftShoulder),
        (.rightShoulder, .rightElbow), (.rightElbow, .rightWrist),
        (.leftShoulder, .leftElbow), (.leftElbow, .leftWrist),
        (.rightShoulder, .rightHip), (.leftShoulder, .leftHip), (.rightHip, .leftHip),
        (.rightHip, .rightKnee), (.rightKnee, .rightAnkle),
        (.leftHip, .leftKnee), (.leftKnee, .leftAnkle),
    ]

    /// A transparent image the size of the frame, so it can be laid over the video with
    /// the same `scaledToFit` the ghosts use — no letterbox maths to get wrong.
    /// The generator must have `appliesPreferredTrackTransform` set: Vision needs the
    /// frame already upright, otherwise it finds fewer people and every joint lands
    /// in the wrong place.
    static func overlay(from gen: AVAssetImageGenerator, at seconds: Double) async -> UIImage? {
        guard let cg = try? await gen.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
        else { return nil }
        let req = VNDetectHumanBodyPoseRequest()
        try? VNImageRequestHandler(cgImage: cg, orientation: .up).perform([req])
        guard let people = req.results, !people.isEmpty else { return nil }

        let size = CGSize(width: cg.width, height: cg.height)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            c.setLineWidth(max(3, size.width / 300))
            c.setLineCap(.round)
            c.setStrokeColor(UIColor.cyan.cgColor)
            c.setFillColor(UIColor.systemPink.cgColor)
            let dot = max(4, size.width / 220)
            for person in people {
                guard let pts = try? person.recognizedPoints(.all) else { continue }
                // Vision's origin is bottom-left, UIKit's is top-left.
                func at(_ p: VNRecognizedPoint) -> CGPoint {
                    CGPoint(x: p.location.x * size.width, y: (1 - p.location.y) * size.height)
                }
                for (a, b) in bones {
                    guard let p = pts[a], let q = pts[b], p.confidence > 0.2, q.confidence > 0.2
                    else { continue }
                    c.move(to: at(p)); c.addLine(to: at(q)); c.strokePath()
                }
                for (_, p) in pts where p.confidence > 0.2 {
                    let m = at(p)
                    c.fillEllipse(in: CGRect(x: m.x - dot / 2, y: m.y - dot / 2, width: dot, height: dot))
                }
            }
        }
    }
}
