import Foundation
import UIKit
import Vision
import GCDWebServer
import PDFKit

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
        
        webServer?.addHandler(forMethod: "GET", path: "/list_pdfs", request: GCDWebServerRequest.self, processBlock: { _ in
            let files = PhotoManager.shared.getAllPDFs().map { $0.lastPathComponent }
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
        
        // Analyze: detect dominant rectangle (for crop hint)
        webServer?.addHandler(forMethod: "GET", path: "/analyze", request: GCDWebServerRequest.self, processBlock: { request in
            guard let fileName = request.query?["file"],
                  !fileName.contains("/"), !fileName.contains("..") else {
                return GCDWebServerDataResponse(jsonObject: ["error": "invalid file"])
            }
            let fileURL = PhotoManager.shared.sharedPhotosDirectory.appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else {
                return GCDWebServerDataResponse(jsonObject: ["error": "cannot load image"])
            }
            if let rect = ImageAnalyzer.detectRectangle(in: image) {
                let response = GCDWebServerDataResponse(jsonObject: rect)
                response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                return response
            } else {
                let response = GCDWebServerDataResponse(jsonObject: ["error": "no rectangle detected"])
                response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                return response
            }
        })
        
        // OCR: recognize text in photo
        webServer?.addHandler(forMethod: "GET", path: "/ocr", request: GCDWebServerRequest.self, processBlock: { request in
            guard let fileName = request.query?["file"],
                  !fileName.contains("/"), !fileName.contains("..") else {
                return GCDWebServerDataResponse(jsonObject: ["error": "invalid file"])
            }
            let fileURL = PhotoManager.shared.sharedPhotosDirectory.appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: data) else {
                return GCDWebServerDataResponse(jsonObject: ["error": "cannot load image"])
            }
            let semaphore = DispatchSemaphore(value: 0)
            var resultText: String? = nil
            ImageAnalyzer.recognizeText(in: image) { text in
                resultText = text
                semaphore.signal()
            }
            semaphore.wait()
            if let text = resultText {
                let response = GCDWebServerDataResponse(jsonObject: ["text": text])
                response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                return response
            } else {
                let response = GCDWebServerDataResponse(jsonObject: ["error": "no text found"])
                response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                return response
            }
        })
        
        // Generate PDF
        webServer?.addHandler(forMethod: "POST", path: "/generate_pdf", request: GCDWebServerDataRequest.self, processBlock: { request in
            guard let dataReq = request as? GCDWebServerDataRequest,
                  let json = try? JSONSerialization.jsonObject(with: dataReq.data, options: []) as? [String: Any],
                  let files = json["files"] as? [String], !files.isEmpty else {
                return GCDWebServerDataResponse(jsonObject: ["error": "invalid request"])
            }
            
            let pdfDocument = PDFDocument()
            let maxDimension: CGFloat = 1600.0 // 限制最大边长，既保证画质清晰，又大幅缩减 PDF 体积
            
            for fileName in files {
                guard !fileName.contains("/"), !fileName.contains(".."), !fileName.lowercased().hasSuffix(".pdf") else { continue }
                let fileURL = PhotoManager.shared.sharedPhotosDirectory.appendingPathComponent(fileName)
                guard let originalImage = UIImage(contentsOfFile: fileURL.path) else { continue }
                
                var finalImage = originalImage
                let currentMaxSide = max(originalImage.size.width, originalImage.size.height)
                
                // 1. 如果图片过大，则按比例缩小尺寸
                if currentMaxSide > maxDimension {
                    let ratio = currentMaxSide / maxDimension
                    let newSize = CGSize(width: originalImage.size.width / ratio, height: originalImage.size.height / ratio)
                    
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1.0 // 固定缩放比为 1，确保使用实际物理像素
                    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
                    let resizedImage = renderer.image { _ in
                        originalImage.draw(in: CGRect(origin: .zero, size: newSize))
                    }
                    
                    // 2. 进一步使用 JPEG 压缩去掉多余的冗余数据
                    if let compressedData = resizedImage.jpegData(compressionQuality: 0.75),
                       let optimizedImage = UIImage(data: compressedData) {
                        finalImage = optimizedImage
                    } else {
                        finalImage = resizedImage
                    }
                } else {
                    // 对于本身不需要缩放的图片，也进行一下适度 JPG 压缩
                    if let compressedData = originalImage.jpegData(compressionQuality: 0.8),
                       let optimizedImage = UIImage(data: compressedData) {
                        finalImage = optimizedImage
                    }
                }
                
                if let pdfPage = PDFPage(image: finalImage) {
                    pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
                }
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let dateStr = formatter.string(from: Date())
            let pdfName = "Images_\(dateStr).pdf"
            let destURL = PhotoManager.shared.sharedPhotosDirectory.appendingPathComponent(pdfName)
            
            if pdfDocument.write(to: destURL) {
                let response = GCDWebServerDataResponse(jsonObject: ["pdf_url": "/photos/\(pdfName)", "pdf_name": pdfName])
                response?.setValue("*", forAdditionalHeader: "Access-Control-Allow-Origin")
                return response
            } else {
                return GCDWebServerDataResponse(jsonObject: ["error": "Failed to generate PDF"])
            }
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
                .img-container img { width: 100%; height: 220px; object-fit: cover; border-radius: 12px; box-shadow: 0 8px 16px rgba(0,0,0,0.5); transition: transform 0.3s; cursor: pointer; display: block; }
                .img-container:hover img { transform: scale(1.05); box-shadow: 0 12px 24px rgba(255,255,255,0.15); }

                .action-bar {
                    position: absolute; bottom: 0; left: 0; right: 0;
                    display: flex; justify-content: space-around; align-items: center;
                    background: linear-gradient(transparent, rgba(0,0,0,0.75));
                    border-radius: 0 0 12px 12px; padding: 8px 6px 6px;
                    opacity: 0; transition: opacity 0.2s; z-index: 20;
                }
                .img-container:hover .action-bar { opacity: 1; }
                .action-btn {
                    flex: 1; margin: 0 3px; padding: 5px 0;
                    background: rgba(255,255,255,0.18); backdrop-filter: blur(4px);
                    color: #fff; border: none; border-radius: 8px;
                    font-size: 13px; cursor: pointer; transition: background 0.15s;
                }
                .action-btn:hover { background: rgba(255,255,255,0.35); }
                .action-btn.del { background: rgba(255,60,60,0.7); }
                .action-btn.del:hover { background: rgba(255,60,60,1); }

                .new-item { animation: pop 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275) forwards; opacity: 0; }
                @keyframes pop { 0% { transform: scale(0.5); opacity: 0; } 100% { transform: scale(1); opacity: 1; } }

                #dropzone {
                    display: none; position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
                    background: rgba(0,255,136,0.85); color: #000; font-size: 40px; font-weight: bold;
                    justify-content: center; align-items: center; z-index: 9999;
                    box-sizing: border-box; border: 15px dashed #000;
                }

                /* Crop modal */
                #crop-modal {
                    display: none; position: fixed; inset: 0;
                    background: rgba(0,0,0,0.92); z-index: 10000;
                    flex-direction: column; align-items: center; justify-content: center;
                }
                #crop-modal.active { display: flex; }
                #crop-wrap { position: relative; display: inline-block; max-width: 90vw; max-height: 78vh; overflow: hidden; }
                #crop-img  { display: block; max-width: 90vw; max-height: 78vh; }
                #crop-box  {
                    position: absolute; border: 2px solid #00ff88;
                    box-shadow: 0 0 0 9999px rgba(0,0,0,0.55);
                    cursor: move; box-sizing: border-box;
                }
                .handle { position: absolute; width: 14px; height: 14px; background: #00ff88; border-radius: 50%; border: 2px solid #000; }
                .handle.tl { top:-7px;  left:-7px;            cursor:nwse-resize; }
                .handle.tr { top:-7px;  right:-7px;           cursor:nesw-resize; }
                .handle.bl { bottom:-7px; left:-7px;          cursor:nesw-resize; }
                .handle.br { bottom:-7px; right:-7px;         cursor:nwse-resize; }
                .handle.tm { top:-7px;  left:calc(50% - 7px); cursor:ns-resize;   }
                .handle.bm { bottom:-7px; left:calc(50% - 7px); cursor:ns-resize; }
                .handle.ml { top:calc(50% - 7px); left:-7px;  cursor:ew-resize;   }
                .handle.mr { top:calc(50% - 7px); right:-7px; cursor:ew-resize;   }
                #crop-actions { margin-top: 18px; display: flex; gap: 14px; }
                .crop-confirm { padding: 10px 36px; background: #00ff88; color: #000; border: none; border-radius: 10px; font-size: 16px; font-weight: bold; cursor: pointer; }
                .crop-cancel  { padding: 10px 36px; background: #333;    color: #fff; border: none; border-radius: 10px; font-size: 16px; cursor: pointer; }
                #crop-hint   { color: #888;    font-size: 13px; margin-top: 8px; }
                #crop-status { color: #00ff88; font-size: 13px; margin-top: 4px; min-height: 20px; }

                /* OCR modal */
                #ocr-modal {
                    display: none; position: fixed; inset: 0;
                    background: rgba(0,0,0,0.88); z-index: 10000;
                    flex-direction: column; align-items: center; justify-content: center;
                }
                #ocr-modal.active { display: flex; }
                #ocr-card {
                    background: #1e1e1e; border-radius: 16px; padding: 28px 32px;
                    max-width: 680px; width: 90%; box-shadow: 0 20px 60px rgba(0,0,0,0.8);
                }
                #ocr-card h3 { margin: 0 0 16px; font-size: 18px; }
                #ocr-text {
                    background: #2a2a2a; border-radius: 10px; padding: 16px;
                    text-align: left; white-space: pre-wrap; line-height: 1.7;
                    max-height: 55vh; overflow-y: auto; font-size: 15px;
                    user-select: text; -webkit-user-select: text; border: 1px solid #333;
                }
                #ocr-actions { margin-top: 18px; display: flex; gap: 12px; justify-content: center; }
                .ocr-copy  { padding: 10px 32px; background: #00ff88; color: #000; border: none; border-radius: 10px; font-size: 15px; font-weight: bold; cursor: pointer; }
                .ocr-close { padding: 10px 24px; background: #333;    color: #fff; border: none; border-radius: 10px; font-size: 15px; cursor: pointer; }
                #copy-tip { color: #00ff88; font-size: 13px; margin-top: 6px; min-height: 18px; }

                /* Multi-select PDF */
                #top-actions { display: flex; justify-content: center; gap: 12px; margin-bottom: 25px; }
                .top-btn { padding: 8px 18px; background: rgba(255,255,255,0.15); border: none; border-radius: 8px; color: #fff; font-size: 15px; cursor: pointer; transition: 0.2s; backdrop-filter: blur(4px); }
                .top-btn:hover { background: rgba(255,255,255,0.25); }
                .top-btn.active-mode { background: #00ff88; color: #000; font-weight: bold; }
                .img-container .check-mark { 
                    position: absolute; top: 10px; right: 10px; width: 26px; height: 26px;
                    border-radius: 50%; border: 2px solid #fff; background: rgba(0,0,0,0.4);
                    display: none; z-index: 10; pointer-events: none; backdrop-filter: blur(2px);
                }
                body.select-mode .img-container .check-mark { display: block; }
                .img-container.selected .check-mark { background: #00ff88; border-color: #00ff88; }
                .img-container.selected .check-mark::after {
                    content: '✓'; color: #000; position: absolute; top: 50%; left: 50%;
                    transform: translate(-50%, -50%); font-weight: bold; font-size: 16px;
                }
                body.select-mode .action-bar { display: none !important; }
                body.select-mode .img-container a { pointer-events: none; }
                body.select-mode .img-container img { transform: scale(0.96); opacity: 0.8; }
                body.select-mode .img-container:hover img { transform: scale(0.96); box-shadow: 0 8px 16px rgba(0,0,0,0.5); }
                body.select-mode .img-container.selected img { transform: scale(1); opacity: 1; border: 3px solid #00ff88; box-sizing: border-box; }
                body.select-mode .img-container.selected:hover img { transform: scale(1.02); }

                /* Tab Switcher */
                .tab-nav { display: flex; justify-content: center; gap: 20px; margin-bottom: 25px; }
                .tab-btn { padding: 10px 24px; font-size: 16px; font-weight: bold; color: #888; background: transparent; border: none; cursor: pointer; border-bottom: 3px solid transparent; transition: 0.2s; }
                .tab-btn.active { color: #00ff88; border-bottom: 3px solid #00ff88; }
                
                #photo-tab-content { display: block; }
                #pdf-tab-content { display: none; text-align: left; max-width: 800px; margin: 0 auto; padding: 0 15px; }

                .pdf-item { display: flex; justify-content: space-between; align-items: center; background: #222; padding: 15px 20px; border-radius: 12px; margin-bottom: 12px; box-shadow: 0 4px 10px rgba(0,0,0,0.3); }
                .pdf-item-info { flex: 1; overflow: hidden; }
                .pdf-item-title { color: #fff; font-size: 16px; margin-bottom: 4px; word-break: break-all; }
                .pdf-item-actions { display: flex; gap: 10px; }
                .pdf-btn { padding: 8px 16px; border: none; border-radius: 8px; font-size: 14px; cursor: pointer; font-weight: bold; }
                .pdf-btn.dl { background: #00ff88; color: #000; text-decoration: none; display: inline-block; }
                .pdf-btn.del { background: #ff3c3c; color: #fff; }

                /* PDF Preview Modal */
                #pdf-modal { display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 10000; flex-direction: column; align-items: center; justify-content: center; backdrop-filter: blur(5px); }
                #pdf-modal.active { display: flex; }
                #pdf-iframe-container { width: 90vw; height: 85vh; background: #fff; border-radius: 12px; overflow: hidden; position: relative; box-shadow: 0 10px 40px rgba(0,0,0,0.8); }
                #pdf-iframe { width: 100%; height: 100%; border: none; }
                #pdf-modal-close { margin-top: 15px; padding: 10px 36px; background: #333; color: #fff; border: none; border-radius: 10px; font-size: 16px; cursor: pointer; transition: 0.2s; }
                #pdf-modal-close:hover { background: #444; }
            </style>
        </head>
        <body>
            <div id="dropzone">松开鼠标，立马传进手机！</div>
            <h2>📸 无延迟实时画廊</h2>
            <div class="tab-nav">
                <button class="tab-btn active" id="btn-tab-photo">📸 相册图库</button>
                <button class="tab-btn" id="btn-tab-pdf">📄 PDF 管理</button>
            </div>

            <div id="photo-tab-content">
                <p>只要手机一拍下照片，瞬间就会在这里自动蹦出来！<br><span style="color:#00ff88;">⬇️ 点击原图下载 | ✂️ 智能裁剪 | 📝 提取文字 | ⬆️ 拖拽上传 | 🗑️ 悬浮删除</span></p>
                <div id="top-actions">
                    <button class="top-btn" id="toggle-select-btn">🔲 多图生成 PDF</button>
                    <button class="top-btn" id="generate-pdf-btn" style="display:none;">📄 生成 PDF (已选0张)</button>
                </div>
                <div id="gallery"></div>
            </div>

            <div id="pdf-tab-content">
                <div style="color:#888; margin-bottom:15px; text-align:center;">这里会显示所有从本地打包生成的 PDF 文件</div>
                <div id="pdf-list"></div>
            </div>

            <!-- PDF Preview Modal -->
            <div id="pdf-modal">
                <div id="pdf-iframe-container">
                    <iframe id="pdf-iframe" src=""></iframe>
                </div>
                <button id="pdf-modal-close">关闭预览</button>
            </div>

            <!-- Crop modal -->
            <div id="crop-modal">
                <div id="crop-wrap">
                    <img id="crop-img" src="" alt="">
                    <div id="crop-box">
                        <div class="handle tl"></div><div class="handle tm"></div><div class="handle tr"></div>
                        <div class="handle ml"></div><div class="handle mr"></div>
                        <div class="handle bl"></div><div class="handle bm"></div><div class="handle br"></div>
                    </div>
                </div>
                <div id="crop-hint">拖动绿框调整裁剪范围</div>
                <div id="crop-status"></div>
                <div id="crop-actions">
                    <button class="crop-confirm" id="crop-confirm-btn">✅ 确认裁剪</button>
                    <button class="crop-cancel"  id="crop-cancel-btn">取消</button>
                </div>
            </div>

            <!-- OCR modal -->
            <div id="ocr-modal">
                <div id="ocr-card">
                    <h3>📝 识别文字结果</h3>
                    <div id="ocr-text"><span style="color:#888;">⏳ 正在识别，请稍候…</span></div>
                    <div id="ocr-actions">
                        <button class="ocr-copy"  id="ocr-copy-btn">一键复制</button>
                        <button class="ocr-close" id="ocr-close-btn">关闭</button>
                    </div>
                    <div id="copy-tip"></div>
                </div>
            </div>

            <script>
                // Tabs Logic
                const btnTabPhoto = document.getElementById('btn-tab-photo');
                const btnTabPdf = document.getElementById('btn-tab-pdf');
                const photoContent = document.getElementById('photo-tab-content');
                const pdfContent = document.getElementById('pdf-tab-content');

                btnTabPhoto.onclick = () => {
                    btnTabPhoto.classList.add('active');
                    btnTabPdf.classList.remove('active');
                    photoContent.style.display = 'block';
                    pdfContent.style.display = 'none';
                };
                btnTabPdf.onclick = () => {
                    btnTabPdf.classList.add('active');
                    btnTabPhoto.classList.remove('active');
                    photoContent.style.display = 'none';
                    pdfContent.style.display = 'block';
                    fetchPdfs();
                };

                // PDF List Management
                const pdfList = document.getElementById('pdf-list');
                function fetchPdfs() {
                    fetch('/list_pdfs').then(r => r.json()).then(files => {
                        pdfList.innerHTML = '';
                        if (files.length === 0) {
                            pdfList.innerHTML = '<div style="text-align:center; color:#555; padding: 40px;">暂无 PDF 文件</div>';
                            return;
                        }
                        files.forEach((f, index) => {
                            let div = document.createElement('div');
                            div.className = 'pdf-item';
                            if (index === 0) div.style.border = '1.5px solid #00ff88';
                            
                            let info = document.createElement('div');
                            info.className = 'pdf-item-info';
                            let titleRow = document.createElement('div');
                            titleRow.style.display = 'flex'; titleRow.style.alignItems = 'center'; titleRow.style.gap = '8px';
                            let title = document.createElement('div');
                            title.className = 'pdf-item-title';
                            title.style.flex = '1';
                            title.textContent = f;
                            titleRow.appendChild(title);
                            if (index === 0) {
                                let badge = document.createElement('span');
                                badge.textContent = '最新';
                                badge.style.cssText = 'background:#00ff88;color:#000;font-size:11px;font-weight:bold;padding:2px 8px;border-radius:20px;white-space:nowrap;';
                                titleRow.appendChild(badge);
                            }
                            info.appendChild(titleRow);
                            
                            let actions = document.createElement('div');
                            actions.className = 'pdf-item-actions';
                            
                            let preview = document.createElement('button');
                            preview.className = 'pdf-btn';
                            preview.textContent = '👁️ 预览';
                            preview.style.background = '#007aff';
                            preview.style.color = '#fff';
                            preview.onclick = () => { openPdfPreview(f); };
                            
                            let dl = document.createElement('a');
                            dl.className = 'pdf-btn dl';
                            dl.textContent = '⬇️ 下载';
                            dl.href = '/photos/' + encodeURIComponent(f);
                            dl.download = f;
                            
                            let del = document.createElement('button');
                            del.className = 'pdf-btn del';
                            del.textContent = '🗑️ 删除';
                            del.onclick = () => {
                                if (confirm('确定要永久删除这个 PDF 吗？')) {
                                    fetch('/delete?file=' + encodeURIComponent(f), { method: 'POST' }).then(() => fetchPdfs());
                                }
                            };
                            
                            actions.appendChild(preview);
                            actions.appendChild(dl);
                            actions.appendChild(del);
                            
                            div.appendChild(info);
                            div.appendChild(actions);
                            pdfList.appendChild(div);
                        });
                    });
                }

                // PDF Preview Logic
                const pdfModal = document.getElementById('pdf-modal');
                const pdfIframe = document.getElementById('pdf-iframe');
                const pdfModalClose = document.getElementById('pdf-modal-close');

                function openPdfPreview(f) {
                    pdfIframe.src = '/photos/' + encodeURIComponent(f);
                    pdfModal.classList.add('active');
                }

                pdfModalClose.onclick = () => {
                    pdfModal.classList.remove('active');
                    setTimeout(() => { pdfIframe.src = ''; }, 300);
                };
                pdfModal.addEventListener('click', (e) => { 
                    if (e.target === pdfModal) {
                        pdfModal.classList.remove('active'); 
                        setTimeout(() => { pdfIframe.src = ''; }, 300);
                    }
                });

                let currentFiles = new Set();
                const gallery = document.getElementById('gallery');

                // Multi-select PDF Logic
                let isSelectMode = false;
                let selectedFiles = new Set();
                const toggleSelectBtn = document.getElementById('toggle-select-btn');
                const generatePdfBtn = document.getElementById('generate-pdf-btn');

                toggleSelectBtn.onclick = () => {
                    isSelectMode = !isSelectMode;
                    if (isSelectMode) {
                        document.body.classList.add('select-mode');
                        toggleSelectBtn.textContent = '❌ 取消多选';
                        toggleSelectBtn.classList.add('active-mode');
                        generatePdfBtn.style.display = 'inline-block';
                        selectedFiles.clear();
                        updateGenerateBtn();
                    } else {
                        document.body.classList.remove('select-mode');
                        toggleSelectBtn.textContent = '🔲 多图生成 PDF';
                        toggleSelectBtn.classList.remove('active-mode');
                        generatePdfBtn.style.display = 'none';
                        document.querySelectorAll('.img-container').forEach(el => el.classList.remove('selected'));
                        selectedFiles.clear();
                    }
                };

                function updateGenerateBtn() {
                    generatePdfBtn.textContent = `📄 生成 PDF (已选${selectedFiles.size}张)`;
                }

                generatePdfBtn.onclick = () => {
                    if (selectedFiles.size === 0) {
                        alert('请先选择图片！'); return;
                    }
                    generatePdfBtn.textContent = '⏳ 正在生成 PDF...';
                    generatePdfBtn.disabled = true;
                    
                    fetch('/generate_pdf', {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ files: Array.from(selectedFiles) })
                    }).then(r => r.json()).then(data => {
                        generatePdfBtn.disabled = false;
                        updateGenerateBtn();
                        if (data.pdf_url) {
                            alert('生成成功！请在【PDF 管理】标签页中查看和下载。');
                            toggleSelectBtn.click(); // Exit select mode
                            btnTabPdf.click(); // Switch to PDF tab
                        } else {
                            alert('生成失败: ' + (data.error || '未知错误'));
                        }
                    }).catch(e => {
                        alert('请求出错，请检查网络');
                        generatePdfBtn.disabled = false;
                        updateGenerateBtn();
                    });
                };

                function createPhotoElement(f, isNew) {
                    let container = document.createElement('div');
                    container.className = 'img-container';
                    if (isNew) container.classList.add('new-item');

                    let check = document.createElement('div');
                    check.className = 'check-mark';
                    container.appendChild(check);

                    container.onclick = (e) => {
                        if (isSelectMode) {
                            e.preventDefault();
                            if (selectedFiles.has(f)) {
                                selectedFiles.delete(f);
                                container.classList.remove('selected');
                            } else {
                                selectedFiles.add(f);
                                container.classList.add('selected');
                            }
                            updateGenerateBtn();
                        }
                    };

                    let a = document.createElement('a');
                    a.href = '/photos/' + encodeURIComponent(f);
                    a.download = f;
                    let img = document.createElement('img');
                    img.src = '/photos/' + encodeURIComponent(f);
                    a.appendChild(img);
                    container.appendChild(a);

                    let bar = document.createElement('div');
                    bar.className = 'action-bar';

                    let cropBtn = document.createElement('button');
                    cropBtn.className = 'action-btn';
                    cropBtn.textContent = '✂️ 裁剪';
                    cropBtn.onclick = (e) => { e.preventDefault(); e.stopPropagation(); openCrop(f); };

                    let ocrBtn = document.createElement('button');
                    ocrBtn.className = 'action-btn';
                    ocrBtn.textContent = '📝 文字';
                    ocrBtn.onclick = (e) => { e.preventDefault(); e.stopPropagation(); openOCR(f); };

                    let delBtn = document.createElement('button');
                    delBtn.className = 'action-btn del';
                    delBtn.textContent = '🗑️ 删除';
                    delBtn.onclick = (e) => {
                        e.preventDefault(); e.stopPropagation();
                        if (confirm('确定要从手机服务器里永久删除这张照片吗?\\n(手机内也会彻底删除)')) {
                            fetch('/delete?file=' + encodeURIComponent(f), { method: 'POST' }).then(() => {
                                currentFiles.delete(f);
                                selectedFiles.delete(f);
                                if (isSelectMode) updateGenerateBtn();
                                container.style.display = 'none';
                            });
                        }
                    };

                    bar.appendChild(cropBtn);
                    bar.appendChild(ocrBtn);
                    bar.appendChild(delBtn);
                    container.appendChild(bar);
                    return container;
                }

                function fetchPhotos() {
                    fetch('/list').then(r => r.json()).then(files => {
                        let imgFiles = files.filter(f => !f.toLowerCase().endsWith('.pdf'));
                        let newFiles = imgFiles.filter(f => !currentFiles.has(f));
                        if (newFiles.length > 0 || imgFiles.length < currentFiles.size) {
                            gallery.innerHTML = '';
                            currentFiles.clear();
                            imgFiles.forEach(f => {
                                currentFiles.add(f);
                                gallery.appendChild(createPhotoElement(f, newFiles.includes(f)));
                            });
                        }
                    }).catch(e => console.log('Poll error:', e));
                }
                fetchPhotos();
                setInterval(fetchPhotos, 800);

                // Drag-drop upload
                const dropzone = document.getElementById('dropzone');
                window.addEventListener('dragover', (e) => { e.preventDefault(); dropzone.style.display = 'flex'; });
                window.addEventListener('dragleave', (e) => { e.preventDefault(); if (e.target === dropzone) dropzone.style.display = 'none'; });
                window.addEventListener('drop', (e) => {
                    e.preventDefault(); dropzone.style.display = 'none';
                    const files = e.dataTransfer.files;
                    if (!files.length) return;
                    const fd = new FormData();
                    for (let i = 0; i < files.length; i++) fd.append('file_' + i, files[i], files[i].name);
                    fetch('/upload', { method: 'POST', body: fd }).then(r => { if (r.ok) fetchPhotos(); });
                });

                // ── Crop ─────────────────────────────────────────────
                const cropModal   = document.getElementById('crop-modal');
                const cropImg     = document.getElementById('crop-img');
                const cropBox     = document.getElementById('crop-box');
                const cropStatus  = document.getElementById('crop-status');
                const cropConfirm = document.getElementById('crop-confirm-btn');
                const cropCancel  = document.getElementById('crop-cancel-btn');
                let cropFile = '';

                function openCrop(f) {
                    cropFile = f;
                    cropStatus.textContent = '';
                    cropModal.classList.add('active');
                    cropImg.onload = () => {
                        const w = cropImg.clientWidth, h = cropImg.clientHeight;
                        setCropBox(w * 0.2, h * 0.2, w * 0.6, h * 0.6);
                        cropStatus.textContent = '⏳ 自动识别文字区域…';
                        fetch('/analyze?file=' + encodeURIComponent(f))
                            .then(r => r.json())
                            .then(data => {
                                if (data.x !== undefined) {
                                    setCropBox(data.x * w, data.y * h, data.width * w, data.height * h);
                                    cropStatus.textContent = '✅ 已自动定位文字区域，可拖动调整';
                                } else {
                                    cropStatus.textContent = '💡 未检测到明显矩形，请手动调整';
                                }
                            })
                            .catch(() => { cropStatus.textContent = '⚠️ 识别失败，请手动调整'; });
                    };
                    cropImg.src = '/photos/' + encodeURIComponent(f) + '?t=' + Date.now();
                }

                function setCropBox(x, y, w, h) {
                    const wrap = document.getElementById('crop-wrap');
                    const mw = wrap.clientWidth, mh = wrap.clientHeight;
                    x = Math.max(0, Math.min(x, mw - 20));
                    y = Math.max(0, Math.min(y, mh - 20));
                    w = Math.max(20, Math.min(w, mw - x));
                    h = Math.max(20, Math.min(h, mh - y));
                    cropBox.style.left   = x + 'px';
                    cropBox.style.top    = y + 'px';
                    cropBox.style.width  = w + 'px';
                    cropBox.style.height = h + 'px';
                }

                (function() {
                    let dragging = false, resizing = false, handle = '';
                    let startX, startY, startL, startT, startW, startH;
                    cropBox.addEventListener('mousedown', (e) => {
                        if (e.target.classList.contains('handle')) {
                            resizing = true;
                            for (let cls of e.target.classList) {
                                if (['tl','tr','bl','br','tm','bm','ml','mr'].includes(cls)) { handle = cls; break; }
                            }
                        } else { dragging = true; }
                        startX = e.clientX; startY = e.clientY;
                        startL = parseInt(cropBox.style.left);  startT = parseInt(cropBox.style.top);
                        startW = parseInt(cropBox.style.width); startH = parseInt(cropBox.style.height);
                        e.preventDefault();
                    });
                    document.addEventListener('mousemove', (e) => {
                        if (!dragging && !resizing) return;
                        const dx = e.clientX - startX, dy = e.clientY - startY;
                        const wrap = document.getElementById('crop-wrap');
                        const mw = wrap.clientWidth, mh = wrap.clientHeight;
                        if (dragging) {
                            cropBox.style.left = Math.max(0, Math.min(startL + dx, mw - startW)) + 'px';
                            cropBox.style.top  = Math.max(0, Math.min(startT + dy, mh - startH)) + 'px';
                        } else {
                            let l = startL, t = startT, w = startW, h = startH;
                            if (handle.includes('r')) { w = Math.max(20, Math.min(startW + dx, mw - l)); }
                            if (handle.includes('l')) { const nw = Math.max(20, startW - dx); l = Math.max(0, startL + startW - nw); w = startW + startL - l; }
                            if (handle.includes('b')) { h = Math.max(20, Math.min(startH + dy, mh - t)); }
                            if (handle.includes('t')) { const nh = Math.max(20, startH - dy); t = Math.max(0, startT + startH - nh); h = startH + startT - t; }
                            cropBox.style.left = l + 'px'; cropBox.style.top  = t + 'px';
                            cropBox.style.width = w + 'px'; cropBox.style.height = h + 'px';
                        }
                    });
                    document.addEventListener('mouseup', () => { dragging = false; resizing = false; });
                })();

                cropConfirm.onclick = () => {
                    cropStatus.textContent = '⏳ 裁剪中…';
                    const dw = cropImg.clientWidth, dh = cropImg.clientHeight;
                    const sx = cropImg.naturalWidth / dw, sy = cropImg.naturalHeight / dh;
                    const bx = parseInt(cropBox.style.left) * sx, by = parseInt(cropBox.style.top) * sy;
                    const bw = parseInt(cropBox.style.width) * sx, bh = parseInt(cropBox.style.height) * sy;
                    const canvas = document.createElement('canvas');
                    canvas.width = bw; canvas.height = bh;
                    const ctx = canvas.getContext('2d');
                    const fullImg = new Image();
                    fullImg.crossOrigin = 'anonymous';
                    fullImg.onload = () => {
                        ctx.drawImage(fullImg, bx, by, bw, bh, 0, 0, bw, bh);
                        canvas.toBlob(blob => {
                            if (!blob) { cropStatus.textContent = '❌ 裁剪失败'; return; }
                            const newName = 'crop_' + cropFile;
                            const fd = new FormData();
                            fd.append('file_0', blob, newName);
                            fetch('/upload', { method: 'POST', body: fd })
                                .then(() => fetch('/delete?file=' + encodeURIComponent(cropFile), { method: 'POST' }))
                                .then(() => { cropModal.classList.remove('active'); fetchPhotos(); })
                                .catch(() => { cropStatus.textContent = '❌ 上传失败'; });
                        }, 'image/jpeg', 0.92);
                    };
                    fullImg.src = '/photos/' + encodeURIComponent(cropFile) + '?t=' + Date.now();
                };
                cropCancel.onclick = () => cropModal.classList.remove('active');
                cropModal.addEventListener('click', (e) => { if (e.target === cropModal) cropModal.classList.remove('active'); });

                // ── OCR ──────────────────────────────────────────────
                const ocrModal   = document.getElementById('ocr-modal');
                const ocrTextDiv = document.getElementById('ocr-text');
                const ocrCopy    = document.getElementById('ocr-copy-btn');
                const ocrClose   = document.getElementById('ocr-close-btn');
                const copyTip    = document.getElementById('copy-tip');
                let ocrResultText = '';

                function openOCR(f) {
                    ocrModal.classList.add('active');
                    ocrTextDiv.innerHTML = '<span style="color:#888;">⏳ 正在识别，请稍候…</span>';
                    copyTip.textContent = '';
                    ocrResultText = '';
                    fetch('/ocr?file=' + encodeURIComponent(f))
                        .then(r => r.json())
                        .then(data => {
                            if (data.text) {
                                ocrResultText = data.text;
                                ocrTextDiv.textContent = data.text;
                            } else {
                                ocrTextDiv.textContent = '⚠️ 未识别到文字，请确认照片中有清晰的文字内容。';
                            }
                        })
                        .catch(() => { ocrTextDiv.textContent = '❌ 识别请求失败，请确认手机服务正在运行。'; });
                }

                ocrCopy.onclick = () => {
                    if (!ocrResultText) return;
                    // navigator.clipboard 仅在 HTTPS/localhost 可用；
                    // 对 http://192.168.x.x 用 execCommand 降级方案
                    const tryExecCommand = () => {
                        const ta = document.createElement('textarea');
                        ta.value = ocrResultText;
                        ta.style.cssText = 'position:fixed;top:0;left:0;opacity:0;';
                        document.body.appendChild(ta);
                        ta.focus(); ta.select();
                        let ok = false;
                        try { ok = document.execCommand('copy'); } catch(e) {}
                        document.body.removeChild(ta);
                        if (ok) {
                            copyTip.textContent = '✅ 已复制到剪贴板！';
                            setTimeout(() => { copyTip.textContent = ''; }, 2500);
                        } else {
                            copyTip.textContent = '⚠️ 请手动选中文字后复制';
                        }
                    };
                    if (navigator.clipboard && window.isSecureContext) {
                        navigator.clipboard.writeText(ocrResultText)
                            .then(() => {
                                copyTip.textContent = '✅ 已复制到剪贴板！';
                                setTimeout(() => { copyTip.textContent = ''; }, 2500);
                            })
                            .catch(tryExecCommand);
                    } else {
                        tryExecCommand();
                    }
                };
                ocrClose.onclick = () => ocrModal.classList.remove('active');
                ocrModal.addEventListener('click', (e) => { if (e.target === ocrModal) ocrModal.classList.remove('active'); });
            </script>
        </body>
        </html>
        """
    }
}