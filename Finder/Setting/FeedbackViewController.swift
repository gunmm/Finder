import UIKit

class FeedbackViewController: UIViewController {
    
    private let textView = UITextView()
    private let placeholderLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("用户反馈", comment: "")
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("取消", comment: ""), style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("提交", comment: ""), style: .done, target: self, action: #selector(submitTapped))
        
        textView.font = .systemFont(ofSize: 16)
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        placeholderLabel.text = NSLocalizedString("请描述您遇到的问题或建议，相关的日志文件将会一并打包上传以帮助我们快速定位修复。", comment: "")
        placeholderLabel.font = .systemFont(ofSize: 16)
        placeholderLabel.textColor = .lightGray
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 200),
            
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 8),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 8),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -8)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: UITextView.textDidChangeNotification, object: textView)
    }
    
    @objc private func textDidChange() {
        placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func submitTapped() {
        let text = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            let alert = UIAlertController(title: NSLocalizedString("提示", comment: ""), message: NSLocalizedString("反馈内容不能为空", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }
        
        view.endEditing(true)
        
        let loadingAlert = UIAlertController(title: NSLocalizedString("正在上传...", comment: ""), message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        AppLogger.shared.log("Submitting Feedback")
        CloudKitManager.shared.uploadFeedback(message: text, logFileURL: AppLogger.shared.currentLogFileURL) { [weak self] success, error in
            loadingAlert.dismiss(animated: true) {
                if success {
                    let alert = UIAlertController(title: NSLocalizedString("提交成功", comment: ""), message: NSLocalizedString("感谢您的反馈！", comment: ""), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default, handler: { _ in
                        self?.dismiss(animated: true)
                    }))
                    self?.present(alert, animated: true)
                } else {
                    let errorMessage = error?.localizedDescription ?? NSLocalizedString("未知错误", comment: "")
                    let alert = UIAlertController(title: NSLocalizedString("提交失败", comment: ""), message: errorMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("重试", comment: ""), style: .default, handler: { [weak self] _ in
                        self?.submitTapped()
                    }))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}
