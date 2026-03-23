import UIKit
import Vision

class ImageAnalyzer {
    
    // MARK: - Rectangle Detection
    
    /// 检测图片中最显眼的矩形区域（如 PPT、黑板、文档）
    /// 返回归一化坐标字典（x, y, width, height），坐标系为左上角原点（百分比 0~1）
    static func detectRectangle(in image: UIImage) -> [String: CGFloat]? {
        guard let cgImage = image.cgImage else { return nil }
        
        var result: [String: CGFloat]? = nil
        let semaphore = DispatchSemaphore(value: 0)
        
        let request = VNDetectRectanglesRequest { req, error in
            defer { semaphore.signal() }
            guard error == nil,
                  let observations = req.results as? [VNRectangleObservation],
                  let best = observations.max(by: { $0.confidence < $1.confidence }) else {
                return
            }
            
            // Vision 坐标系：原点在左下角，Y 轴朝上
            // 转换为：原点在左上角（Web/UIKit 标准）
            let bx = best.boundingBox.origin.x
            let bw = best.boundingBox.width
            let bh = best.boundingBox.height
            // Vision y 是矩形底边距底部的距离，UIKit y 是矩形顶边距顶部的距离
            let by = 1.0 - best.boundingBox.origin.y - bh
            
            result = [
                "x": bx,
                "y": by,
                "width": bw,
                "height": bh,
                "confidence": CGFloat(best.confidence)
            ]
        }
        
        // 调整参数以适配 PPT/文档类大矩形
        request.minimumConfidence = 0.6
        request.minimumAspectRatio = 0.2
        request.maximumObservations = 5
        
        let orientation = cgImageOrientation(from: image)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("[ImageAnalyzer] Rectangle detection error: \(error)")
        }
        
        semaphore.wait()
        return result
    }
    
    // MARK: - OCR
    
    /// 识别图片中的文字，支持中英文混排
    /// 结果以换行分隔，通过 completion 回调异步返回
    static func recognizeText(in image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { req, error in
            guard error == nil,
                  let observations = req.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            if lines.isEmpty {
                completion(nil)
            } else {
                completion(lines.joined(separator: "\n"))
            }
        }
        
        // 精准模式 + 中英文并识
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
        request.usesLanguageCorrection = true
        
        let orientation = cgImageOrientation(from: image)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("[ImageAnalyzer] OCR error: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Helpers
    
    /// 将 UIImage 的方向转换为 CGImagePropertyOrientation（Vision 需要此参数保证方向正确）
    private static func cgImageOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
