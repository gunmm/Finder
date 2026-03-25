import Foundation
import UIKit

class PhotoManager {
    static let shared = PhotoManager()
    
    let sharedPhotosDirectory: URL
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        sharedPhotosDirectory = documentsDirectory.appendingPathComponent("SharedPhotos")
        
        // Ensure directory exists
        if !FileManager.default.fileExists(atPath: sharedPhotosDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: sharedPhotosDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating SharedPhotos directory: \(error)")
            }
        }
    }
    
    func savePhoto(_ image: UIImage) -> Bool {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return false }
        let fileName = "IMG_\(Int(Date().timeIntervalSince1970)).jpg"
        let fileURL = sharedPhotosDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Error saving photo: \(error)")
            return false
        }
    }
    
    func getAllPhotos() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sharedPhotosDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            // Sort by descending date
            return files.filter { 
                let ext = $0.pathExtension.lowercased()
                return ["jpg", "jpeg", "png", "heic", "gif"].contains(ext) 
            }
            .sorted { u1, u2 in
                let d1 = (try? u1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return d1 > d2
            }
        } catch {
            print("Error getting photos: \(error)")
            return []
        }
    }
    
    func getAllPDFs() -> [URL] {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: sharedPhotosDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            return files.filter { $0.pathExtension.lowercased() == "pdf" }
            .sorted { u1, u2 in
                let d1 = (try? u1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let d2 = (try? u2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return d1 > d2
            }
        } catch {
            print("Error getting PDFs: \(error)")
            return []
        }
    }
    
    func deletePhoto(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Error deleting photo: \(error)")
            return false
        }
    }
}
