import UIKit
import StoreKit

class TipViewController: UIViewController {

    // MARK: - Product IDs
    private let productIDs: [String] = [
        "com.syl.Finder.small",
        "com.syl.Finder.medium",
        "com.syl.Finder.big"
    ]

    private var products: [SKProduct] = []
    private var loadingTiers: Set<String> = []

    // MARK: - UI
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.alignment = .center
        sv.spacing = 0
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    // --- Header ---
    private let heartIcon: UILabel = {
        let l = UILabel()
        l.text = "🌸"
        l.font = .systemFont(ofSize: 64)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "感谢你的打赏！"
        l.font = .systemFont(ofSize: 26, weight: .bold)
        l.textColor = .label
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "独立开发不容易，你的每一份支持\n都是我继续前行最大的动力 💪"
        l.font = .systemFont(ofSize: 15)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // --- Tip Options ---
    private let optionsStack: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 16
        sv.alignment = .fill
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let sectionLabel: UILabel = {
        let l = UILabel()
        l.text = "选择打赏档位"
        l.font = .systemFont(ofSize: 13, weight: .semibold)
        l.textColor = .tertiaryLabel
        l.textAlignment = .left
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // Per-tier buttons
    private var smallButton: TipOptionButton!
    private var mediumButton: TipOptionButton!
    private var bigButton: TipOptionButton!

    // MARK: - Full-screen Loading Overlay
    private lazy var loadingOverlay: UIView = {
        let overlay = UIView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        overlay.alpha = 0
        overlay.isUserInteractionEnabled = true

        // 毛玻璃卡片
        let blur = UIBlurEffect(style: .systemMaterialDark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 20
        blurView.clipsToBounds = true
        overlay.addSubview(blurView)

        // 菊花
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        blurView.contentView.addSubview(spinner)

        // 文字
        let label = UILabel()
        label.text = "请求中..."
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor.white.withAlphaComponent(0.85)
        label.translatesAutoresizingMaskIntoConstraints = false
        blurView.contentView.addSubview(label)

        NSLayoutConstraint.activate([
            blurView.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            blurView.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
            blurView.widthAnchor.constraint(equalToConstant: 130),
            blurView.heightAnchor.constraint(equalToConstant: 110),

            spinner.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            spinner.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 22),

            label.centerXAnchor.constraint(equalTo: blurView.contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 12)
        ])

        return overlay
    }()

    private let footerLabel: UILabel = {
        let l = UILabel()
        l.text = "付款将通过 Apple Pay / App Store 完成\n购买后不支持退款，感谢理解 🙏"
        l.font = .systemFont(ofSize: 12)
        l.textColor = .quaternaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "打赏"
        view.backgroundColor = .systemGroupedBackground
        setupUI()
        fetchProducts()
        SKPaymentQueue.default().add(self)
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }

    // MARK: - Setup
    private func setupUI() {
        // Build tier buttons
        smallButton  = TipOptionButton(emoji: "🌱", title: "小赏一下", subtitle: "发芽啦", productID: productIDs[0])
        mediumButton = TipOptionButton(emoji: "🌻", title: "中赏一波", subtitle: "发发哒",  productID: productIDs[1])
        bigButton    = TipOptionButton(emoji: "🌈", title: "大赏一记", subtitle: "发大财啦", productID: productIDs[2])

        [smallButton, mediumButton, bigButton].forEach { btn in
            btn?.addTarget(self, action: #selector(tipButtonTapped(_:)), for: .touchUpInside)
            btn?.setLoading(true)   // show loading until prices arrive
            optionsStack.addArrangedSubview(btn!)
        }

        // Scroll
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        // --- Header spacer ---
        let headerPad = spacer(height: 40)
        contentStack.addArrangedSubview(headerPad)
        contentStack.addArrangedSubview(heartIcon)
        contentStack.setCustomSpacing(16, after: heartPad())
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(12, after: titleLabel)
        contentStack.addArrangedSubview(subtitleLabel)
        contentStack.setCustomSpacing(40, after: subtitleLabel)

        // --- Section label + options ---
        let optionsWrapper = UIView()
        optionsWrapper.translatesAutoresizingMaskIntoConstraints = false
        optionsWrapper.addSubview(sectionLabel)
        optionsWrapper.addSubview(optionsStack)
        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: optionsWrapper.topAnchor),
            sectionLabel.leadingAnchor.constraint(equalTo: optionsWrapper.leadingAnchor, constant: 4),
            sectionLabel.trailingAnchor.constraint(equalTo: optionsWrapper.trailingAnchor),

            optionsStack.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 10),
            optionsStack.leadingAnchor.constraint(equalTo: optionsWrapper.leadingAnchor),
            optionsStack.trailingAnchor.constraint(equalTo: optionsWrapper.trailingAnchor),
            optionsStack.bottomAnchor.constraint(equalTo: optionsWrapper.bottomAnchor)
        ])

        contentStack.addArrangedSubview(optionsWrapper)
        NSLayoutConstraint.activate([
            optionsWrapper.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -48)
        ])

        contentStack.setCustomSpacing(36, after: optionsWrapper)
        contentStack.addArrangedSubview(footerLabel)
        contentStack.setCustomSpacing(50, after: footerLabel)
        contentStack.addArrangedSubview(spacer(height: 0))
    }

    private func heartPad() -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return v
    }

    private func spacer(height: CGFloat) -> UIView {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: height).isActive = true
        return v
    }

    // MARK: - StoreKit: Fetch Products
    private func fetchProducts() {
        let request = SKProductsRequest(productIdentifiers: Set(productIDs))
        request.delegate = self
        request.start()
    }

    // MARK: - Purchase
    @objc private func tipButtonTapped(_ sender: TipOptionButton) {
        guard SKPaymentQueue.canMakePayments() else {
            showAlert(title: "无法完成购买", message: "您的设备不支持应用内购买，请检查家长控制或账户设置。")
            return
        }
        guard let product = products.first(where: { $0.productIdentifier == sender.productID }) else {
            showAlert(title: "商品未加载", message: "请稍候再试，或检查网络连接。")
            return
        }
        sender.setLoading(true)
        showLoadingOverlay()
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    // MARK: - Helpers
    private func button(for productID: String) -> TipOptionButton? {
        switch productID {
        case productIDs[0]: return smallButton
        case productIDs[1]: return mediumButton
        case productIDs[2]: return bigButton
        default: return nil
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "好的", style: .default))
        present(alert, animated: true)
    }

    private func showTipSuccess() {
        let alert = UIAlertController(
            title: "打赏成功！🎉",
            message: "非常感谢您的慷慨支持！\n您的鼓励是开发者前行最大的动力，我一定会更加努力，把 App 做得更好！",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "一起加油！💪", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Loading Overlay
    private func showLoadingOverlay() {
        guard loadingOverlay.superview == nil else { return }
        // 挂到 window 的最顶层，不受 scrollView 裁剪影响
        let target: UIView = view.window ?? view
        target.addSubview(loadingOverlay)
        NSLayoutConstraint.activate([
            loadingOverlay.topAnchor.constraint(equalTo: target.topAnchor),
            loadingOverlay.leadingAnchor.constraint(equalTo: target.leadingAnchor),
            loadingOverlay.trailingAnchor.constraint(equalTo: target.trailingAnchor),
            loadingOverlay.bottomAnchor.constraint(equalTo: target.bottomAnchor)
        ])
        UIView.animate(withDuration: 0.2) {
            self.loadingOverlay.alpha = 1
        }
    }

    private func hideLoadingOverlay() {
        UIView.animate(withDuration: 0.2, animations: {
            self.loadingOverlay.alpha = 0
        }, completion: { _ in
            self.loadingOverlay.removeFromSuperview()
        })
    }
}

// MARK: - SKProductsRequestDelegate
extension TipViewController: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.products = response.products.sorted { a, b in
                guard let ia = self.productIDs.firstIndex(of: a.productIdentifier),
                      let ib = self.productIDs.firstIndex(of: b.productIdentifier) else { return false }
                return ia < ib
            }
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            for product in self.products {
                formatter.locale = product.priceLocale
                let priceStr = formatter.string(from: product.price) ?? "\(product.price)"
                self.button(for: product.productIdentifier)?.setPriceLabel(priceStr)
                self.button(for: product.productIdentifier)?.setLoading(false)
            }
            // If some products failed to load, keep them disabled but remove spinner
            let loadedIDs = Set(self.products.map { $0.productIdentifier })
            self.productIDs.forEach { id in
                if !loadedIDs.contains(id) {
                    self.button(for: id)?.setPriceLabel("--")
                    self.button(for: id)?.setLoading(false)
                    self.button(for: id)?.isEnabled = false
                }
            }
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.productIDs.forEach { id in
                self.button(for: id)?.setPriceLabel("加载失败")
                self.button(for: id)?.setLoading(false)
                self.button(for: id)?.isEnabled = false
            }
        }
    }
}

// MARK: - SKPaymentTransactionObserver
extension TipViewController: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            let productID = transaction.payment.productIdentifier
            switch transaction.transactionState {
            case .purchased:
                SKPaymentQueue.default().finishTransaction(transaction)
                DispatchQueue.main.async { [weak self] in
                    self?.hideLoadingOverlay()
                    self?.button(for: productID)?.setLoading(false)
                    self?.showTipSuccess()
                }
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
                DispatchQueue.main.async { [weak self] in
                    self?.hideLoadingOverlay()
                    self?.button(for: productID)?.setLoading(false)
                    if let err = transaction.error as? SKError, err.code == .paymentCancelled {
                        // User cancelled — do nothing
                    } else {
                        let msg = transaction.error?.localizedDescription ?? "未知错误，请重试。"
                        self?.showAlert(title: "购买失败", message: msg)
                    }
                }
            case .restored:
                SKPaymentQueue.default().finishTransaction(transaction)
            default:
                break
            }
        }
    }
}


// MARK: - TipOptionButton

class TipOptionButton: UIControl {

    let productID: String

    private let emojiLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 32)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .semibold)
        l.textColor = .label
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 13)
        l.textColor = .secondaryLabel
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let priceLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 15, weight: .semibold)
        l.textColor = .systemOrange
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let spinner: UIActivityIndicatorView = {
        let av = UIActivityIndicatorView(style: .medium)
        av.hidesWhenStopped = true
        av.translatesAutoresizingMaskIntoConstraints = false
        return av
    }()

    private let chevron: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "chevron.right"))
        iv.tintColor = .tertiaryLabel
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    override var isHighlighted: Bool {
        didSet { UIView.animate(withDuration: 0.12) { self.alpha = self.isHighlighted ? 0.6 : 1.0 } }
    }

    override var isEnabled: Bool {
        didSet { alpha = isEnabled ? 1.0 : 0.4 }
    }

    init(emoji: String, title: String, subtitle: String, productID: String) {
        self.productID = productID
        super.init(frame: .zero)
        emojiLabel.text = emoji
        titleLabel.text = title
        subtitleLabel.text = subtitle
        setupCard()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCard() {
        backgroundColor = .secondarySystemGroupedBackground
        layer.cornerRadius = 16
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.06
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 6
        translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let rightStack = UIStackView(arrangedSubviews: [priceLabel, spinner])
        rightStack.axis = .horizontal
        rightStack.spacing = 6
        rightStack.alignment = .center
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(emojiLabel)
        addSubview(textStack)
        addSubview(rightStack)
        addSubview(chevron)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 80),

            emojiLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            emojiLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 14),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: rightStack.leadingAnchor, constant: -8),

            chevron.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),

            rightStack.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            rightStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func setPriceLabel(_ price: String) {
        priceLabel.text = price
    }

    func setLoading(_ loading: Bool) {
        if loading {
            spinner.startAnimating()
            priceLabel.isHidden = true
            chevron.isHidden = true
            isUserInteractionEnabled = false
        } else {
            spinner.stopAnimating()
            priceLabel.isHidden = false
            chevron.isHidden = false
            isUserInteractionEnabled = true
        }
    }
}

