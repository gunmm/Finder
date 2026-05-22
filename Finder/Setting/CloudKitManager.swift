import Foundation
import CloudKit

class CloudKitManager {
    static let shared = CloudKitManager()
    
    private let publicDatabase = CKContainer.default().publicCloudDatabase
    
    func uploadFeedback(message: String, logFileURL: URL? = nil, completion: @escaping (Bool, Error?) -> Void) {
        let record = CKRecord(recordType: "Feedback")
        record["message"] = message as CKRecordValue
        record["timestamp"] = Date() as CKRecordValue
        
        if let fileURL = logFileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            let asset = CKAsset(fileURL: fileURL)
            record["logFile"] = asset
        }
        
        publicDatabase.save(record) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                } else {
                    completion(true, nil)
                }
            }
        }
    }
}
