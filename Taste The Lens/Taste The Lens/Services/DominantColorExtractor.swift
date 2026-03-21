import UIKit
import CoreImage

struct DominantColorExtractor {
    /// Extracts dominant colors from an image by sampling grid regions with CIAreaAverage.
    /// Returns hex strings (e.g., "#A83B2F"). Runs on a downsized copy for speed.
    static func extractColors(from image: UIImage, count: Int = 6) -> [String] {
        let small = image.resizedForAPIUpload(maxDimension: 200)
        guard let ciImage = CIImage(image: small) else { return [] }

        let context = CIContext(options: [.workingColorSpace: NSNull()])
        let extent = ciImage.extent

        // Divide into a grid (3 columns x 2 rows = 6 regions)
        let cols = 3
        let rows = 2
        let regionWidth = extent.width / CGFloat(cols)
        let regionHeight = extent.height / CGFloat(rows)

        var colors: [(hex: String, r: CGFloat, g: CGFloat, b: CGFloat)] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let regionRect = CGRect(
                    x: extent.origin.x + CGFloat(col) * regionWidth,
                    y: extent.origin.y + CGFloat(row) * regionHeight,
                    width: regionWidth,
                    height: regionHeight
                )

                guard let filter = CIFilter(name: "CIAreaAverage") else { continue }
                filter.setValue(ciImage, forKey: kCIInputImageKey)
                filter.setValue(CIVector(cgRect: regionRect), forKey: kCIInputExtentKey)

                guard let output = filter.outputImage else { continue }

                var pixel = [UInt8](repeating: 0, count: 4)
                context.render(
                    output,
                    toBitmap: &pixel,
                    rowBytes: 4,
                    bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                    format: .RGBA8,
                    colorSpace: CGColorSpaceCreateDeviceRGB()
                )

                let r = CGFloat(pixel[0])
                let g = CGFloat(pixel[1])
                let b = CGFloat(pixel[2])
                let hex = String(format: "#%02X%02X%02X", pixel[0], pixel[1], pixel[2])

                // Skip near-black and near-white colors
                let brightness = (r + g + b) / 3.0
                if brightness < 15 || brightness > 240 { continue }

                // Deduplicate: skip if too similar to an existing color
                let isSimilar = colors.contains { existing in
                    abs(existing.r - r) + abs(existing.g - g) + abs(existing.b - b) < 60
                }
                if !isSimilar {
                    colors.append((hex, r, g, b))
                }
            }
        }

        return Array(colors.prefix(count).map(\.hex))
    }
}
