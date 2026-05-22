import Foundation

class AppLogger {
    static let shared = AppLogger()
    
    private let logFileURL: URL
    private let queue = DispatchQueue(label: "com.syl.LongScreenShot.AppLogger")
    private var fileHandle: FileHandle?
    
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        logFileURL = docs.appendingPathComponent("app_activity.log")
        
        // 如果日志过大跳过（1MB）
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? UInt64, size > 1024 * 1024 {
            try? FileManager.default.removeItem(at: logFileURL)
        }
        
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil, attributes: nil)
        }
        
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        if #available(iOS 13.4, *) {
            try? fileHandle?.seekToEnd()
        } else {
            fileHandle?.seekToEndOfFile()
        }
    }
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    func log(_ message: String) {
        let timeString = AppLogger.dateFormatter.string(from: Date())
        let formattedMessage = "[\(timeString)] \(message)\n"
        
        print(formattedMessage, terminator: "")
        
        queue.async {
            guard let data = formattedMessage.data(using: .utf8) else { return }
            if #available(iOS 13.4, *) {
                try? self.fileHandle?.write(contentsOf: data)
            } else {
                self.fileHandle?.write(data)
            }
        }
    }
    
    var currentLogFileURL: URL {
        return logFileURL
    }
}
