//
//  SettingsViewController.swift
//  Microphone
//
//  Created by minzhe on 2026/1/11.
//

import UIKit

class SettingsViewController: UIViewController {


    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = NSLocalizedString("Settings", comment: "")
        
        setupButtons()
        
        // 导航栏关闭按钮
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
        )
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    // Adding button to setupUI
    func setupButtons() {
        // 放大主按钮的字号
        feedbackButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        
        let stackView = UIStackView(arrangedSubviews: [reviewButton, tipButton, feedbackButton])
        stackView.axis = .vertical
        stackView.spacing = 30
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            // Center top buttons
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60)
        ])
    }
    

    
    // MARK: - Center Buttons
    
    private lazy var reviewButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Rate Us", comment: ""), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.addTarget(self, action: #selector(reviewButtonTapped), for: .touchUpInside)
        return button
    }()
    
    @objc private func reviewButtonTapped() {
        AppLogger.shared.log("Tapped Review button")
        if let url = URL(string: "https://apps.apple.com/app/id6760936076?action=write-review") {
            UIApplication.shared.open(url)
        }
    }

    private lazy var tipButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Tip", comment: ""), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.addTarget(self, action: #selector(tipButtonTapped), for: .touchUpInside)
        return button
    }()
    
    @objc private func tipButtonTapped() {
        AppLogger.shared.log("Tapped Tip button")
        let vc = TipViewController()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
    
    private lazy var feedbackButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("Feedback & Help", comment: ""), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.addTarget(self, action: #selector(feedbackButtonTapped), for: .touchUpInside)
        return button
    }()
    
    @objc private func feedbackButtonTapped() {
        AppLogger.shared.log("Tapped Feedback button")
        let vc = FeedbackViewController()
        let nav = UINavigationController(rootViewController: vc)
        present(nav, animated: true)
    }
}
