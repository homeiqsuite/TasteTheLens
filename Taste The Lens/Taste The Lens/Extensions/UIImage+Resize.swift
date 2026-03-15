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
}
