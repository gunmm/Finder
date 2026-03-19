import Foundation
import GCDWebServer

class ServerManager {
    static let shared = ServerManager()
    
    private var webServer: GCDWebServer?
    
    var liveURL: URL? { return webServer?.serverURL }
    var isLiveWebRunning: Bool { return webServer?.isRunning ?? false }
    
    private init() {
        self.webServer = GCDWebServer()
        
        webServer?.addGETHandler(forBasePath: "/photos/", directoryPath: PhotoManager.shared.sharedPhotosDirectory.path, indexFilename: nil, cacheAge: 0, allowRangeRequests: true)
        
        webServer?.addHandler(forMethod: "GET", path: "/list", request: GCDWebServerRequest.self, processBlock: { _ in
            let files = PhotoManager.shared.getAllPhotos().map { $0.lastPathComponent }
            return GCDWebServerDataResponse(jsonObject: files)
        })
        
        webServer?.addHandler(forMethod: "POST", path: "/upload", request: GCDWebServerMultiPartFormRequest.self, processBlock: { request in
            guard let multipartRequest = request as? GCDWebServerMultiPartFormRequest else {
                return GCDWebServerResponse(statusCode: 400)
            }
            for multiPartFile in multipartRequest.files {
                let tempPath = multiPartFile.temporaryPath
                let fileName = multiPartFile.fileName
                let destURL = PhotoManager.shared.sharedPhotosDirectory.appendingPathComponent(fileName)
                do {
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.moveItem(atPath: tempPath, toPath: destURL.path)
                } catch {
                    print("Upload save error: \(error)")
                }
            }
            return GCDWebServerResponse(statusCode: 200)
        })
        
        // Delete API
        webServer?.addHandler(forMethod: "POST", path: "/delete", request: GCDWebServerRequest.self, processBlock: { request in
            if let fileName = request.query?["file"] {
                if !fileName.contains("/") && !fileName.contains("..") {
                    let fileURL = PhotoManager.shared.sharedPhotosDirectory.appendingPathComponent(fileName)
                    _ = PhotoManager.shared.deletePhoto(at: fileURL)
                }
            }
            return GCDWebServerResponse(statusCode: 200)
        })
        
        webServer?.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self, processBlock: { [weak self] _ in
            let html = self?.getLiveHTML() ?? ""
            return GCDWebServerDataResponse(html: html)
        })
    }
    
    func startLiveWeb() -> Bool {
        guard let web = webServer else { return false }
        if web.isRunning { return true }
        GCDWebServer.setLogLevel(3)
        do {
            try web.start(options: [
                GCDWebServerOption_Port: 8080,
                GCDWebServerOption_BonjourName: "实时网页图库",
                GCDWebServerOption_AutomaticallySuspendInBackground: false
            ])
            return true
        } catch {
            print("[Web] ❌ 启动失败: \(error.localizedDescription)")
            return false
        }
    }
    
    func stopLiveWeb() {
        webServer?.stop()
    }
    
    private func getLiveHTML() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <title>手机实时相册</title>
            <style>
                body { background: #121212; color: #fff; font-family: -apple-system, sans-serif; text-align: center; margin: 0; padding: 30px; }
                h2 { margin-bottom: 5px; letter-spacing: 1px; }
                p { color: #888; font-size: 15px; margin-top: 0; margin-bottom: 30px; }
                #gallery { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 20px; padding: 10px; max-width: 1200px; margin: auto; }
                a { text-decoration: none; outline: none; display: block; }
                
                .img-container { position: relative; width: 100%; border-radius: 12px; }
                img { width: 100%; height: 220px; object-fit: cover; border-radius: 12px; box-shadow: 0 8px 16px rgba(0,0,0,0.5); transition: transform 0.3s; cursor: pointer; display: block; }
                .img-container:hover img { transform: scale(1.05); box-shadow: 0 12px 24px rgba(255,255,255,0.15); z-index: 10; }
                
                .delete-btn {
                    position: absolute; top: 8px; right: 8px; width: 32px; height: 32px;
                    background: rgba(255, 60, 60, 0.85); color: white; border-radius: 16px;
                    display: flex; justify-content: center; align-items: center; 
                    cursor: pointer; font-size: 18px; font-weight: bold; 
                    opacity: 0; transition: all 0.2s; z-index: 20; box-shadow: 0 4px 8px rgba(0,0,0,0.5);
                }
                .img-container:hover .delete-btn { opacity: 1; }
                .delete-btn:hover { background: red; transform: scale(1.15); }

                .new-item { animation: pop 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards; opacity: 0; }
                @keyframes pop { 0% { transform: scale(0.5); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }
                
                #dropzone {
                    display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
                    background: rgba(0, 255, 136, 0.85); color: #000; font-size: 40px; font-weight: bold;
                    justify-content: center; align-items: center; z-index: 9999;
                    box-sizing: border-box; border: 15px dashed #000;
                }
            </style>
        </head>
        <body>
            <div id="dropzone">松开鼠标，立马传进手机！</div>
            <h2>📸 无延迟实时画廊</h2>
            <p>只要手机一拍下照片，瞬间就会在这里自动蹦出来！<br><span style="color:#00ff88;">⬇️ 点击原图下载 | ⬆️ 直接往里拖拽文件上传 | 🗑️ 鼠标悬浮右上角点击彻底删除</span></p>
            <div id="gallery"></div>
            <script>
                let currentFiles = new Set();
                const gallery = document.getElementById('gallery');
                
                function createPhotoElement(f, isNew) {
                    let container = document.createElement('div');
                    container.className = 'img-container';
                    if (isNew) container.classList.add('new-item');
                    
                    let a = document.createElement('a');
                    a.href = '/photos/' + encodeURIComponent(f);
                    a.download = f; 
                    
                    let img = document.createElement('img');
                    img.src = '/photos/' + encodeURIComponent(f);
                    
                    let delBtn = document.createElement('div');
                    delBtn.className = 'delete-btn';
                    delBtn.innerHTML = '✕';
                    delBtn.onclick = (e) => {
                        e.preventDefault();
                        e.stopPropagation();
                        if(confirm('确定要从手机服务器里永久删除这块照片吗？\\n(不仅本地看不到了，手机内也会彻底被粉碎)')) {
                            fetch('/delete?file=' + encodeURIComponent(f), { method: 'POST' }).then(() => {
                                currentFiles.delete(f);
                                container.style.display = 'none';
                            });
                        }
                    };
                    
                    a.appendChild(img);
                    container.appendChild(a);
                    container.appendChild(delBtn);
                    
                    return container;
                }
                
                function fetchPhotos() {
                    fetch('/list').then(r => r.json()).then(files => {
                        let newFiles = files.filter(f => !currentFiles.has(f));
                        
                        // 发现服务器上有新文件/丢失文件差异需要大刷新或者追加
                        if (newFiles.length > 0 || files.length < currentFiles.size) {
                            
                            gallery.innerHTML = '';
                            currentFiles.clear();
                            
                            files.forEach(f => {
                                currentFiles.add(f);
                                let item = createPhotoElement(f, newFiles.includes(f));
                                gallery.appendChild(item);
                            });
                        }
                    }).catch(e => console.log("轮询错误:", e));
                }
                
                fetchPhotos();
                setInterval(fetchPhotos, 800);
                
                const dropzone = document.getElementById('dropzone');
                
                window.addEventListener('dragover', (e) => {
                    e.preventDefault();
                    dropzone.style.display = 'flex';
                });
                
                window.addEventListener('dragleave', (e) => {
                    e.preventDefault();
                    if(e.target === dropzone) {
                        dropzone.style.display = 'none';
                    }
                });
                
                window.addEventListener('drop', (e) => {
                    e.preventDefault();
                    dropzone.style.display = 'none';
                    
                    const files = e.dataTransfer.files;
                    if(files.length === 0) return;
                    
                    const formData = new FormData();
                    for(let i=0; i<files.length; i++){
                        formData.append('file_' + i, files[i], files[i].name);
                    }
                    
                    fetch('/upload', { method: 'POST', body: formData })
                        .then(resp => {
                            if(resp.ok) { fetchPhotos(); }
                        })
                        .catch(err => console.error("上传错误", err));
                });
            </script>
        </body>
        </html>
        """
    }
}
