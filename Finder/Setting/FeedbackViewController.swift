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
        title = NSLocalizedString("User Feedback", comment: "")
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Cancel", comment: ""), style: .plain, target: self, action: #selector(cancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: NSLocalizedString("Submit", comment: ""), style: .done, target: self, action: #selector(submitTapped))
        
        textView.font = .systemFont(ofSize: 16)
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.layer.borderWidth = 1
        textView.layer.cornerRadius = 8
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        
        placeholderLabel.text = NSLocalizedString("Feedback Prompt", comment: "")
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
            let alert = UIAlertController(title: NSLocalizedString("Notice", comment: ""), message: NSLocalizedString("Feedback Empty", comment: ""), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
            present(alert, animated: true)
            return
        }
        
        view.endEditing(true)
        
        let loadingAlert = UIAlertController(title: NSLocalizedString("Uploading...", comment: ""), message: nil, preferredStyle: .alert)
        present(loadingAlert, animated: true)
        
        AppLogger.shared.log("Submitting Feedback")
        CloudKitManager.shared.uploadFeedback(message: text, logFileURL: AppLogger.shared.currentLogFileURL) { [weak self] success, error in
            loadingAlert.dismiss(animated: true) {
                if success {
                    let alert = UIAlertController(title: NSLocalizedString("Submit Successful", comment: ""), message: NSLocalizedString("Thank you for feedback!", comment: ""), preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default, handler: { _ in
                        self?.dismiss(animated: true)
                    }))
                    self?.present(alert, animated: true)
                } else {
                    let errorMessage = error?.localizedDescription ?? NSLocalizedString("Unknown Error", comment: "")
                    let alert = UIAlertController(title: NSLocalizedString("Submit Failed", comment: ""), message: errorMessage, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: NSLocalizedString("重试", comment: ""), style: .default, handler: { [weak self] _ in
                        self?.submitTapped()
                    }))
                    alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
}
