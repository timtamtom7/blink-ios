import AVFoundation
import UIKit

actor ThumbnailGenerator {
    static let shared = ThumbnailGenerator()

    private init() {}

    func generateThumbnail(for videoURL: URL, videoFilename: String) async -> String? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 200, height: 200)

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)

        do {
            let cgImage = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CGImage, Error>) in
                imageGenerator.generateCGImageAsynchronously(for: time) { generatedImage, actualTime, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else if let generatedImage = generatedImage {
                        continuation.resume(returning: generatedImage)
                    } else {
                        continuation.resume(throwing: NSError(domain: "ThumbnailGenerator", code: -1))
                    }
                }
            }
            let uiImage = UIImage(cgImage: cgImage)

            let thumbFilename = videoFilename.replacingOccurrences(of: ".mov", with: "_thumb.jpg")
            let thumbURL = VideoStore.shared.videosDirectory.appendingPathComponent(thumbFilename)

            if let jpegData = uiImage.jpegData(compressionQuality: 0.7) {
                try jpegData.write(to: thumbURL)
                return thumbFilename
            }
        } catch {
            print("Thumbnail generation failed: \(error)")
        }

        return nil
    }
}
