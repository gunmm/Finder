import UIKit
import QuickLook

class PreviewViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, UITableViewDataSource, UITableViewDelegate, QLPreviewControllerDataSource {
    
    private var segmentedControl: UISegmentedControl!
    private var collectionView: UICollectionView!
    private var tableView: UITableView!
    
    private var photos: [URL] = []
    private var pdfs: [URL] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "文件预览"
        view.backgroundColor = .systemBackground
        
        setupSegmentedControl()
        setupCollectionView()
        setupTableView()
        
        updateViewVisibility()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
    }
    
    private func setupSegmentedControl() {
        segmentedControl = UISegmentedControl(items: ["相册 照片", "生成的 PDF"])
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged), for: .valueChanged)
        
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
        NSLayoutConstraint.activate([
            segmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            segmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            segmentedControl.widthAnchor.constraint(equalToConstant: 240)
        ])
    }
    
    @objc private func segmentChanged() {
        updateViewVisibility()
    }
    
    private func updateViewVisibility() {
        if segmentedControl.selectedSegmentIndex == 0 {
            collectionView.isHidden = false
            tableView.isHidden = true
        } else {
            collectionView.isHidden = true
            tableView.isHidden = false
        }
    }
    
    @objc private func refreshData() {
        loadData()
        collectionView.refreshControl?.endRefreshing()
        tableView.refreshControl?.endRefreshing()
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 2
        let itemWidth = (view.bounds.width - spacing * 2) / 3
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        view.addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 15),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: .zero, style: .plain)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "PDFCell")
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 15),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
    }
    
    private func loadData() {
        self.photos = PhotoManager.shared.getAllPhotos()
        self.pdfs = PhotoManager.shared.getAllPDFs()
        collectionView.reloadData()
        tableView.reloadData()
    }
    
    // MARK: - UICollectionViewDataSource & Delegate (Photos)
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let photoURL = photos[indexPath.item]
        
        DispatchQueue.global().async {
            if let imageData = try? Data(contentsOf: photoURL), let image = UIImage(data: imageData) {
                DispatchQueue.main.async {
                    cell.imageView.image = image
                }
            }
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let photoURL = photos[indexPath.item]
        let detailVC = PhotoDetailViewController(photoURL: photoURL)
        navigationController?.pushViewController(detailVC, animated: true)
    }
    
    // MARK: - UITableViewDataSource & Delegate (PDFs)
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return pdfs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PDFCell", for: indexPath)
        let pdfURL = pdfs[indexPath.row]
        cell.textLabel?.text = pdfURL.lastPathComponent
        cell.imageView?.image = UIImage(systemName: "doc.text")
        cell.accessoryType = .disclosureIndicator
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.currentPreviewItemIndex = indexPath.row
        navigationController?.pushViewController(previewController, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let fileURL = pdfs[indexPath.row]
            if PhotoManager.shared.deletePhoto(at: fileURL) {
                pdfs.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
    }
    
    // MARK: - QLPreviewControllerDataSource
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return pdfs.count
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return pdfs[index] as QLPreviewItem
    }
}

class PhotoCell: UICollectionViewCell {
    let imageView = UIImageView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.addSubview(imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
    }
}
