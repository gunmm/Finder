import UIKit

class ViewController: UIViewController {
    
    // UI Components for Live Web Gallery
    let webSwitch = UISwitch()
    let webStatusLabel = UILabel()
    let webIpLabel = UILabel()
    
    // Buttons
    let cameraButton = UIButton(type: .system)
    let galleryButton = UIButton(type: .system)
    let settingsButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("Live Web Gallery Title", comment: "")
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Tip", comment: ""), style: .plain, target: self, action: #selector(showTipTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Instructions", comment: ""), style: .plain, target: self, action: #selector(showInstructionsTapped))
        
        setupUI()
        setupConstraints()
        
        AppLogger.shared.log("ViewController viewDidLoad")
    }
    
    private func setupUI() {
        // --- Live Web Section ---
        webStatusLabel.text = NSLocalizedString("Web Service Off", comment: "")
        webStatusLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        webStatusLabel.textColor = .label
        webStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webStatusLabel)
        
        webSwitch.isOn = false
        webSwitch.addTarget(self, action: #selector(webSwitchChanged(_:)), for: .valueChanged)
        webSwitch.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webSwitch)
        
        webIpLabel.text = NSLocalizedString("IP Address: --", comment: "")
        webIpLabel.font = .systemFont(ofSize: 15)
        webIpLabel.textColor = .secondaryLabel
        webIpLabel.numberOfLines = 0
        webIpLabel.isUserInteractionEnabled = true
        webIpLabel.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(handleIpLongPress(_:))))
        webIpLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webIpLabel)
        
        // --- Buttons Section ---
        cameraButton.setTitle(NSLocalizedString("Take Photo", comment: ""), for: .normal)
        cameraButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        cameraButton.backgroundColor = .systemBlue
        cameraButton.setTitleColor(.white, for: .normal)
        cameraButton.layer.cornerRadius = 12
        cameraButton.addTarget(self, action: #selector(takePhotoTapped), for: .touchUpInside)
        cameraButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraButton)
        
        galleryButton.setTitle(NSLocalizedString("Local Preview", comment: ""), for: .normal)
        galleryButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        galleryButton.backgroundColor = .systemGreen
        galleryButton.setTitleColor(.white, for: .normal)
        galleryButton.layer.cornerRadius = 12
        galleryButton.addTarget(self, action: #selector(previewPhotosTapped), for: .touchUpInside)
        galleryButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(galleryButton)
        
        let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)
        settingsButton.setImage(UIImage(systemName: "gearshape.fill", withConfiguration: config), for: .normal)
        settingsButton.tintColor = .systemBlue
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsButton)
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
            galleryButton.heightAnchor.constraint(equalToConstant: 60),
            
            settingsButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            settingsButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            settingsButton.widthAnchor.constraint(equalToConstant: 36),
            settingsButton.heightAnchor.constraint(equalToConstant: 36)
        ])
    }
    
    // MARK: - Actions
    @objc private func showTipTapped() {
        AppLogger.shared.log("Tapped Tip button from ViewController")
        let tipVC = TipViewController()
        navigationController?.pushViewController(tipVC, animated: true)
    }
    
    @objc private func showInstructionsTapped() {
        AppLogger.shared.log("Tapped Instructions button from ViewController")
        let instructionsVC = InstructionsViewController()
        navigationController?.pushViewController(instructionsVC, animated: true)
    }
    
    @objc private func webSwitchChanged(_ sender: UISwitch) {
        AppLogger.shared.log("Toggled Live Web Switch to \(sender.isOn)")
        if sender.isOn {
            if ServerManager.shared.startLiveWeb() {
                webStatusLabel.text = NSLocalizedString("Web Service On", comment: "")
                let urlStr = ServerManager.shared.liveURL?.absoluteString ?? NSLocalizedString("Getting IP...", comment: "")
                webIpLabel.text = "\(NSLocalizedString("Open Browser URL", comment: "")) \(urlStr) (\(""))"
            } else {
                sender.isOn = false
                webStatusLabel.text = NSLocalizedString("Web Service Failed", comment: "")
            }
        } else {
            ServerManager.shared.stopLiveWeb()
            webStatusLabel.text = NSLocalizedString("Web Service Off", comment: "")
            webIpLabel.text = NSLocalizedString("IP Address: --", comment: "")
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
        
        let alert = UIAlertController(title: NSLocalizedString("Copied", comment: ""), message: urlText, preferredStyle: .alert)
        present(alert, animated: true)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            alert.dismiss(animated: true)
        }
    }
    
    @objc private func takePhotoTapped() {
        AppLogger.shared.log("Tapped Take Photo button")
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = self
            present(picker, animated: true)
        } else {
            let alert = UIAlertController(title: NSLocalizedString("No Camera", comment: ""), message: NSLocalizedString("Camera Not Supported", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func previewPhotosTapped() {
        AppLogger.shared.log("Tapped Preview Photos button")
        let previewVC = PreviewViewController()
        navigationController?.pushViewController(previewVC, animated: true)
    }
    
    @objc private func settingsTapped() {
        AppLogger.shared.log("Tapped Settings button from ViewController")
        let settingsVC = SettingsViewController()
        let nav = UINavigationController(rootViewController: settingsVC)
        present(nav, animated: true)
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
