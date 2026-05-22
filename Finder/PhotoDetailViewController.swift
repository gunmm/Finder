import UIKit

class PhotoDetailViewController: UIViewController, UIScrollViewDelegate {
    
    let photoURL: URL
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    
    init(photoURL: URL) {
        self.photoURL = photoURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "大图详情"
        
        setupScrollView()
        setupImageView()
        setupNavigationBar()
        loadImage()
    }
    
    private func setupScrollView() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 5.0
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // 双击放大/缩小手势
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
    }
    
    private func setupImageView() {
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            
            // 使得图片在缩放前能居中显示并填满视口
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
    }
    
    private func setupNavigationBar() {
        // 重命名保存按钮为“保存”以省空间
        let saveButton = UIBarButtonItem(title: NSLocalizedString("Save", comment: ""), style: .done, target: self, action: #selector(saveToAlbumTapped))
        
        // 添加红色垃圾桶删除按钮
        let deleteButton = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePhotoTapped))
        deleteButton.tintColor = .systemRed
        
        navigationItem.rightBarButtonItems = [saveButton, deleteButton]
    }
    
    private func loadImage() {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            if let data = try? Data(contentsOf: self.photoURL), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(title: NSLocalizedString("Load Failed", comment: ""), message: NSLocalizedString("Cannot Read Photo", comment: ""))
                }
            }
        }
    }
    
    // MARK: - UIScrollViewDelegate
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    // 缩放时保证图片在屏幕中间而不是贴在左上角
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + offsetX,
                                   y: scrollView.contentSize.height * 0.5 + offsetY)
    }
    
    // MARK: - Actions
    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1.0 {
            // 已放大时双击还原
            scrollView.setZoomScale(1.0, animated: true)
        } else {
            // 未放大时双击特定焦点放大到 3.0 倍
            let point = recognizer.location(in: imageView)
            let zoomRect = zoomRectForScale(scale: 3.0, center: point)
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    private func zoomRectForScale(scale: CGFloat, center: CGPoint) -> CGRect {
        var zoomRect = CGRect.zero
        zoomRect.size.height = imageView.frame.size.height / scale
        zoomRect.size.width  = imageView.frame.size.width  / scale
        zoomRect.origin.x = center.x - (zoomRect.size.width / 2.0)
        zoomRect.origin.y = center.y - (zoomRect.size.height / 2.0)
        return zoomRect
    }
    
    @objc private func deletePhotoTapped() {
        let alert = UIAlertController(title: NSLocalizedString("Delete Photo Confirm", comment: ""), message: NSLocalizedString("Delete Photo Warning", comment: ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil))
        
        let deleteAction = UIAlertAction(title: NSLocalizedString("Permanent Delete", comment: ""), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            // 从系统中擦除文件
            if PhotoManager.shared.deletePhoto(at: self.photoURL) {
                // 删除成功后返回上一页网格
                self.navigationController?.popViewController(animated: true)
            } else {
                self.showAlert(title: NSLocalizedString("Delete Failed", comment: ""), message: NSLocalizedString("Delete Failed Reason", comment: ""))
            }
        }
        alert.addAction(deleteAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    @objc private func saveToAlbumTapped() {
        guard let image = imageView.image else { return }
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showAlert(title: NSLocalizedString("Save Failed", comment: ""), message: error.localizedDescription)
        } else {
            showAlert(title: NSLocalizedString("Save Success", comment: ""), message: NSLocalizedString("Saved to Album", comment: ""))
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
