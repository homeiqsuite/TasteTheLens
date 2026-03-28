import UIKit

extension UIImage {
    func resizedForAPIUpload(maxDimension: CGFloat = 1024) -> UIImage {
        let aspectRatio = size.width / size.height
        let newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: min(size.width, maxDimension), height: min(size.width, maxDimension) / aspectRatio)
        } else {
            newSize = CGSize(width: min(size.height, maxDimension) * aspectRatio, height: min(size.height, maxDimension))
        }

        guard newSize.width < size.width || newSize.height < size.height else { return self }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    func jpegDataForUpload(quality: CGFloat = 0.8, maxDimension: CGFloat = 1024) -> Data? {
        resizedForAPIUpload(maxDimension: maxDimension).jpegData(compressionQuality: quality)
    }

    /// Compress existing JPEG Data for cloud upload (max 2048px, 0.8 quality).
    /// Returns the original data if it's already small enough.
    static func compressForCloudUpload(_ data: Data, maxBytes: Int = 5_000_000) -> Data {
        guard data.count > maxBytes, let image = UIImage(data: data) else { return data }
        return image.jpegDataForUpload(quality: 0.8, maxDimension: 2048) ?? data
    }
}
