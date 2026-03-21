import UIKit

class InstructionsViewController: UIViewController {
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .systemBackground
        return scrollView
    }()
    
    private let contentLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 16)
        label.textColor = .label
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "使用说明"
        view.backgroundColor = .systemBackground
        
        setupUI()
        configureContent()
    }
    
    private func setupUI() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentLabel.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            contentLabel.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentLabel.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentLabel.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            
            // Limit the width of the contentLabel to the width of the scrollView
            contentLabel.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }
    
    private func configureContent() {
        let instructionsText = """
        Finder 使用说明

        功能介绍：
        Finder 是一款局域网网页相机与图库应用，可以让你随时随地无需数据线，即可通过 Wi-Fi 在电脑浏览器上方便地查看、上传、下载和管理手机里的照片。

        具体使用步骤：
        1. 连接同一 Wi-Fi：请确保你的手机和电脑（或平板）连接在同一个局域网（Wi-Fi）下。
        2. 开启网页图库服务：在 App 主界面中，打开“网页实时追踪服务”开关。开启成功后，下方会显示“🌍 浏览器打开: http://192.168.x.x:8080”以及具体的 IP 网址。
        3. 浏览器访问：在电脑或设备上的电脑浏览器地址栏中，输入显示的 IP 地址并回车。此时你已经可以在网页中看到专属的图库操作页面。
           （小提示：在手机端长按 IP 地址，可以一键复制链接）
        4. 实时拍照与同步：在 App 主界面点击“📸 拍照”按钮，相机会自动捕捉并保存，同时网页端会自动刷新，能够立刻在电脑上看到你刚用手机拍摄的照片，实现秒传体验！
        5. 网页端操作：在浏览器网页中，你可以选中任意照片原图进行下载；可以直接将电脑里的照片拖拽上传到手机云端相册中；也可以直接在网页上轻松地删除不需要的旧照片。
        6. 本地预览管理：在 App 主界面点击“🖼 手机本地预览”，你可以随时使用手机原生界面直接浏览、预览或管理所有已传输及拍摄并存储在应用内的共享照片。

        祝你使用愉快！
        """
        
        // Add some paragraph styling if desired
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 8
        
        let attributedText = NSAttributedString(string: instructionsText, attributes: [
            .font: UIFont.systemFont(ofSize: 16),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: UIColor.label
        ])
        
        contentLabel.attributedText = attributedText
    }
}
