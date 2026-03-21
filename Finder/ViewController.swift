import UIKit

class ViewController: UIViewController {
    
    // UI Components for Live Web Gallery
    let webSwitch = UISwitch()
    let webStatusLabel = UILabel()
    let webIpLabel = UILabel()
    
    // Buttons
    let cameraButton = UIButton(type: .system)
    let galleryButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "实时网页相机"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "使用说明", style: .plain, target: self, action: #selector(showInstructionsTapped))
        
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        // --- Live Web Section ---
        webStatusLabel.text = "网页实时追踪服务: 关闭"
        webStatusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        webStatusLabel.textColor = .label
        webStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webStatusLabel)
        
        webSwitch.isOn = false
        webSwitch.addTarget(self, action: #selector(webSwitchChanged(_:)), for: .valueChanged)
        webSwitch.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webSwitch)
        
        webIpLabel.text = "IP 地址: --"
        webIpLabel.font = .systemFont(ofSize: 15)
        webIpLabel.textColor = .secondaryLabel
        webIpLabel.numberOfLines = 0
        webIpLabel.isUserInteractionEnabled = true
        webIpLabel.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleIpLongPress(_:))))
        webIpLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webIpLabel)
        
        // --- Buttons Section ---
        cameraButton.setTitle("📸 拍照", for: .normal)
        cameraButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        cameraButton.backgroundColor = .systemBlue
        cameraButton.setTitleColor(.white, for: .normal)
        cameraButton.layer.cornerRadius = 12
        cameraButton.addTarget(self, action: #selector(takePhotoTapped), for: .touchUpInside)
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraButton)
        
        galleryButton.setTitle("🖼 手机本地预览", for: .normal)
        galleryButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        galleryButton.backgroundColor = .systemGreen
        galleryButton.setTitleColor(.white, for: .normal)
        galleryButton.layer.cornerRadius = 12
        galleryButton.addTarget(self, action: #selector(previewPhotosTapped), for: .touchUpInside)
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(galleryButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Live Web
            webSwitch.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            webSwitch.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            webStatusLabel.centerYAnchor.constraint(equalTo: webSwitch.centerYAnchor),
            webStatusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            webStatusLabel.trailingAnchor.constraint(lessThanOrEqualTo: webSwitch.leadingAnchor, constant: -10),
            
            webIpLabel.topAnchor.constraint(equalTo: webSwitch.bottomAnchor, constant: 15),
            webIpLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            webIpLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),
            
            // Buttons
            cameraButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cameraButton.topAnchor.constraint(equalTo: webIpLabel.bottomAnchor, constant: 60),
            cameraButton.widthAnchor.constraint(equalToConstant: 260),
            cameraButton.heightAnchor.constraint(equalToConstant: 60),
            
            galleryButton.topAnchor.constraint(equalTo: cameraButton.bottomAnchor, constant: 30),
            galleryButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            galleryButton.widthAnchor.constraint(equalToConstant: 260),
            galleryButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    // MARK: - Actions
    @objc private func showInstructionsTapped() {
        let instructionsVC = InstructionsViewController()
        navigationController?.pushViewController(instructionsVC, animated: true)
    }
    
    @objc private func webSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            if ServerManager.shared.startLiveWeb() {
                webStatusLabel.text = "网页图库服务: 开启"
                let urlStr = ServerManager.shared.liveURL?.absoluteString ?? "正在获取局域网IP..."
                webIpLabel.text = "🌍 浏览器打开: \(urlStr) (长按复制链接)"
            } else {
                sender.isOn = false
                webStatusLabel.text = "网页图库服务: 启动失败"
            }
        } else {
            ServerManager.shared.stopLiveWeb()
            webStatusLabel.text = "网页图库服务: 关闭"
            webIpLabel.text = "IP 地址: --"
        }
    }
    
    @objc private func handleIpLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began,
              let label = recognizer.view as? UILabel,
              let text = label.text else { return }
        
        guard let range = text.range(of: "http://") else { return }
        var urlText = String(text[range.lowerBound...])
        if let spaceIndex = urlText.firstIndex(of: " ") {
            urlText = String(urlText[..<spaceIndex])
        }
        
        UIPasteboard.general.string = urlText
        
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        let alert = UIAlertController(title: "已复制", message: urlText, preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    @objc private func takePhotoTapped() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            present(picker, animated: true)
        } else {
            let alert = UIAlertController(title: "无相机", message: "此设备不支持相机或正运行于模拟器", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func previewPhotosTapped() {
        let previewVC = PreviewViewController()
        navigationController?.pushViewController(previewVC, animated: true)
    }
}

extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true) {
            if let image = info[.originalImage] as? UIImage {
                let success = PhotoManager.shared.savePhoto(image)
                print("Photo saved: \(success)")
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}
