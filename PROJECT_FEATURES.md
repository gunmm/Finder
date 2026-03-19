# Finder 项目功能与实现说明 (AI 读取专用)

## 1. 项目概述
Finder（实时网页相机/图库）是一款 iOS 应用，主要功能是提供设备的实时照片共享与跨端管理。用户在 App 内拍照后，同一局域网下的电脑端可以通过浏览器实时查看、下载、甚至上传和删除照片，无需通过 USB 数据线连接或挂载网络驱动器。

## 2. 核心功能及架构逻辑

### 2.1 本地 Web 服务器 (GCDWebServer)
- **实现类**: `Finder/ServerManager.swift`
- **底层依赖**: `GCDWebServer` (`~> 3.5`，通过 CocoaPods 引入)
- **工作机制**: 
  - 启动后默认监听 `8080` 端口。
  - **路由设计**:
    1. `GET /photos/`：直接映射到本地存储目录，提供静态图片及文件访问。
    2. `GET /list`：返回目录下所有照片文件名的 JSON 列表，供前端轮询比对。
    3. `POST /upload`：接收 Web 端拖拽上传的文件（Multipart Form 格式），存储在本地目录。
    4. `POST /delete`：接收 `?file=xxx` 参数，调用本地照片管理器物理彻底删除照片。
    5. `GET /`：返回极简的实时 HTML 前端页面（直接在 Swift 代码中以多行字符串 `getLiveHTML()` 返回）。
- **前端实时性机制**: Web 页面通过 `setInterval(fetchPhotos, 800)` 每 800ms 轮询一次 `/list` 接口，比对已有文件名集合（`currentFiles`），发现新文件/缺失文件即动态更新 DOM，实现“手机拍照、网页秒出”的效果。

### 2.2 本地照片与文件管理
- **实现类**: `Finder/PhotoManager.swift`
- **存储位置**: 沙盒文档目录下的 `Documents/SharedPhotos` 文件夹
- **主要职责**:
  - `savePhoto(_ image: UIImage)`：将相机拍摄的照片保存为 `JPEG` 格式（0.8 质量压缩），按时间戳生成文件名（例如 `IMG_169xxxxxxx.jpg`）。
  - `getAllPhotos()`：遍历目标目录中的所有文件，过滤后缀为 jpg/jpeg/png/heic/gif 的图片文件，并按文件创建时间进行降序排列（确保最新拍的照片在前端页面最前展示）。
  - `deletePhoto(at url: URL)`：物理彻底删除指定照片文件。

### 2.3 用户界面与原生控制
- **实现类**: `Finder/ViewController.swift`, `Finder/PreviewViewController.swift`, `Finder/PhotoDetailViewController.swift`
- **页面功能**:
  - **服务控制台**：包含一个 `UISwitch` 用来控制开启和关闭局域网服务器服务 (`ServerManager.shared.startLiveWeb()`)。开启后会通过 UILabel 显示局域网的内网 IP 地址供电脑访问。支持长按复制该 URL 地址。
  - **拍照上传入口**：调用系统的 `UIImagePickerController` (配置为 `.camera` 作为来源)。用户拍照拍完后，自动调用 `PhotoManager.shared.savePhoto` 保存，由前端轮询接口自行提取并在 Web 里展现。
  - **本地原生相册**：通过入口按钮可跳转到 `PreviewViewController`，并在内部使用 `PhotoDetailViewController` 查看照片详情，用于在手机 App 内直接原生查看和管理已有的云端/本地共享照片。

## 3. 面向 AI 的后续修改建议与约束

1. **前后端代码耦合 (需注意)**：目前前端 HTML/CSS/JS 高度耦合在 `ServerManager.swift` 的一个字符串文本中。如果要对 Web 网页进行样式增强、增加复杂的特效或 UI 改进，修改时请极其注意多行字符串的转义，并建议在条件允许的情况下，将这坨前端代码剥离为一个单独存放的 `index.html` 资源文件。
2. **媒体格式扩展**：目前 `PhotoManager` 中的 `getAllPhotos` 只放开了对 `.jpg, .jpeg, .png, .heic, .gif` 类型的支持。若需添加实时视频分享（如 `.mp4`, `.mov`），需在后端该过滤白名单中增加相应后缀，并且在前端 Web 的 JS 渲染流中判断后缀以使用 `<video>` 标签渲染。
3. **并发安全与文件锁**：`PhotoManager` 中的读写目前属于简单文件系统操作，未显式使用串行队列等锁机制控制。但鉴于 `GCDWebServer` 会在后台多线程并发触发 API（尤其是多文件批量上传时），未来如果有耗时更久的处理逻辑，建议增加文件读写的锁队列来防止崩溃或文件损坏。
4. **状态刷新广播**：目前 Web 端纯靠轮询同步新图片。如果未来要优化性能，可以考虑使用 WebSocket 替代长链接轮询方式，一旦 iOS 端录入新照片，由服务端 PUSH 通知前端进行拉取数据。

---
> 提示：如果希望对本项目界面、网页或功能进行更改，请首先阅读本文档理解现有生命周期，再通过相应的 Manager 类进行拦截和注入。
