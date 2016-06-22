import UIKit

class SnapImagePickerViewController: UIViewController {
    @IBOutlet weak var mainScrollView: UIScrollView?
    @IBOutlet weak var selectedImageScrollView: UIScrollView?
    @IBOutlet weak var selectedImageView: UIImageView? {
        didSet {
            selectedImageView?.frame = CGRect(x: 0, y: 0, width: 320, height: 320)
        }
    }
    @IBOutlet weak var albumCollectionView: UICollectionView?
    @IBOutlet weak var albumSelectorView: AlbumSelectorView?

    var albums = [PhotoAlbum]() {
        didSet {
            albumSelectorView?.albums = albums
        }
    }
    var currentlySelectedAlbum = 0 {
        didSet {
            if currentlySelectedAlbum < albums.count {
                state = .Image
                let title = albums[currentlySelectedAlbum].title
                setupAlbumCollectionView(title)
                mainAlbumTitle?.titleLabel?.text = title
            }
        }
    }
    
    var selectedImage: UIImage? {
        didSet {
            setupSelectedImageScrollView()
        }
    }
    var images = [(id: String, image: UIImage)]() {
        didSet {
            if let albumCollectionView = albumCollectionView {
                albumCollectionView.reloadData()
            }
        }
    }
    
    @IBOutlet weak var albumSelectorTopConstraint: NSLayoutConstraint?
    @IBOutlet weak var imageAndAlbumSpacingConstraint: NSLayoutConstraint?
    
    
    private var state = DisplayState.Image {
        didSet {
            setMainOffsetFor(state)
        }
    }
    
    private var albumSelectorIsShowing: Bool {
        return albumSelectorTopConstraint?.constant == UIConstants.TopBarHeight
    }
    
    @IBAction func collectionsButtonClicked(sender: UIButton) {
        if albumSelectorIsShowing {
            hideCollectionsView()
       } else {
            showCollectionsView()
        }
    }
    
    var currentlySelectedIndex = 0 {
        didSet {
            albumCollectionView?.reloadData()
        }
    }
    
    var interactor: AlbumInteractorInput?
    var delegate: SnapImagePickerDelegate?
    
    private struct UIConstants {
        static let Spacing = CGFloat(2)
        static let NumberOfColumns = 4
        static let BackgroundColor = UIColor.whiteColor()
        static let MaxZoomScale = 5.0
        static let CellBorderWidth = CGFloat(3.0)
        static let TopBarHeight = CGFloat(44.0)
        
        static func CellWidthInView(collectionView: UICollectionView) -> CGFloat {
            return (collectionView.bounds.width - (Spacing * CGFloat(NumberOfColumns - 1))) / CGFloat(NumberOfColumns)
        }
    }
    
    private let OffsetThreshold = CGFloat(0.65)
    enum DisplayState: Double {
        case Image = 0.0
        case Album = 0.85
    }
    
    override func viewDidLoad() {
        mainScrollView!.contentSize = CGSize(width: 300, height: 300)
        setupSelectedImageScrollView()
        setupAlbumCollectionView("Album")
        setupGestureRecognizers()
        setupCollectionsView()
        hideCollectionsView()
        interactor?.fetchAlbumPreviews()
        imageAndAlbumSpacingConstraint?.constant = UIConstants.Spacing
        
        selectedImageScrollView?.userInteractionEnabled = true
    }
    
    @IBAction func acceptImageButtonPressed(sender: UIButton) {
        if let selectedImageScrollView = selectedImageScrollView,
           let selectedImageView = selectedImageView,
           let selectedImage = selectedImageView.image {
            let visibleRect = selectedImageScrollView.convertRect(selectedImageScrollView.bounds, toView: selectedImageView)
            let ratio = max(selectedImage.size.width, selectedImage.size.height) / selectedImageView.bounds.width
            let transformedVisibleRect = CGRect(x: visibleRect.minX * ratio,
                                                y: visibleRect.minY * ratio,
                                                width: visibleRect.width * ratio,
                                                height: visibleRect.height * ratio)

            var verticalOffset = CGFloat(0.0)
            var horizontalOffset = CGFloat(0.0)
            if selectedImage.size.width > selectedImage.size.height {
                verticalOffset = (selectedImage.size.width - selectedImage.size.height) / 2
            } else {
                horizontalOffset = (selectedImage.size.height - selectedImage.size.width) / 2
            }
            
            let cropRect = CGRect(x: transformedVisibleRect.minX - horizontalOffset,
                                  y: transformedVisibleRect.minY - verticalOffset,
                                  width: transformedVisibleRect.width,
                                  height: transformedVisibleRect.height)
            
            delegate?.pickedImage(selectedImage, withBounds: cropRect)
        }
        dismiss()
    }
    
    @IBOutlet weak var mainAlbumTitle: UIButton?
    @IBAction func cancelButtonPressed(sender: UIButton) {
        dismiss()
    }
    
    private func dismiss() {
        self.dismissViewControllerAnimated(false, completion: nil)
    }
}

extension SnapImagePickerViewController {

    private func showCollectionsView() {
        albumSelectorTopConstraint?.constant = UIConstants.TopBarHeight
        UIView.animateWithDuration(NSTimeInterval(0.5)) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func hideCollectionsView() {
        albumSelectorTopConstraint?.constant = self.view.frame.height
        UIView.animateWithDuration(NSTimeInterval(0.5)) {
            self.view.layoutIfNeeded()
        }
    }
}

extension SnapImagePickerViewController {
    private func setupSelectedImageScrollView() {
        if let scrollView = selectedImageScrollView,
           let imageView = selectedImageView,
           let image = selectedImage {
            scrollView.setZoomScale(1.0, animated: false)
            imageView.contentMode = .ScaleAspectFit
            imageView.image = image
            imageView.frame = CGRect(x: 0, y: 0, width: scrollView.frame.width, height: scrollView.frame.height)
            scrollView.contentSize = CGSize(width: imageView.bounds.width, height: imageView.bounds.height)
            
            var zoomScale = CGFloat(1.0)
            if image.size.width > image.size.height {
                zoomScale = image.size.width/image.size.height
            } else if image.size.height > image.size.width {
                zoomScale = image.size.height/image.size.width
            }
        
            scrollView.setZoomScale(zoomScale, animated: false)
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = CGFloat(UIConstants.MaxZoomScale)
            scrollView.delegate = self
        }
    }
    
    private func setupAlbumCollectionView(title: String) {
        if let albumCollectionView = albumCollectionView {
            SnapImagePicker.setupAlbumViewController(self)
            albumCollectionView.dataSource = self
            albumCollectionView.delegate = self
            albumCollectionView.backgroundColor = UIConstants.BackgroundColor
            if let interactor = interactor {
                images = [(id: String, image: UIImage)]()
                let imageCellWidth = UIConstants.CellWidthInView(albumCollectionView)
                interactor.fetchAlbum(Album_Request(title: title, size: CGSize(width: imageCellWidth, height: imageCellWidth)))
            }
        }
    }
    
    private func setupCollectionsView() {
        if let albumSelectorView = albumSelectorView {
            view.addSubview(albumSelectorView)
            albumSelectorView.dataSource = albumSelectorView
            albumSelectorView.albums = albums
            albumSelectorView.delegate = self
        }
    }
}

extension SnapImagePickerViewController: UICollectionViewDataSource {
    func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return (images.count / UIConstants.NumberOfColumns) + 1
    }

    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return min(UIConstants.NumberOfColumns, images.count)
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        if let cell = collectionView.dequeueReusableCellWithReuseIdentifier("Image Cell", forIndexPath: indexPath) as? ImageCell {
            let index = indexPathToArrayIndex(indexPath)
            if index < images.count {
                if index == currentlySelectedIndex {
                    let border = UIConstants.CellBorderWidth
                    cell.imageView?.frame = CGRect(x: border, y: border, width: cell.bounds.width - (2 * border), height: cell.bounds.height - (2 * border))
                    cell.backgroundColor = SnapImagePicker.color
                } else {
                    cell.imageView?.frame = CGRect(x: 0, y: 0, width: cell.bounds.width, height: cell.bounds.height)
                }
                cell.imageView?.image = images[index].image
            }
            
            return cell
        }
        return UICollectionViewCell()
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let size = UIConstants.CellWidthInView(collectionView)
        return CGSize(width: size, height: size)
    }
    
    private func indexPathToArrayIndex(indexPath: NSIndexPath) -> Int {
        return indexPath.section * UIConstants.NumberOfColumns + indexPath.row
    }
}

extension SnapImagePickerViewController: UICollectionViewDelegate {
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let index = indexPathToArrayIndex(indexPath)
        if let selectedImageScrollView = selectedImageScrollView {
            let width = selectedImageScrollView.bounds.width
            setMainOffsetFor(.Image)
            currentlySelectedIndex = index
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                self.interactor?.fetchImage(Image_Request(id: self.images[index].id, size: CGSize(width: width, height: width)))
            }
        }
    }
}

protocol AlbumViewControllerInput : class {
    func displayAlbumImage(response: Image_Response)
    func displayMainImage(response: Image_Response)
    func addAlbumPreview(album: PhotoAlbum)
}

extension SnapImagePickerViewController: AlbumViewControllerInput {
    func displayAlbumImage(response: Image_Response) {
        self.images.append((id: response.id, image: response.image))
        if let selectedImageScrollView = selectedImageScrollView
            where images.count == 1 {
            let width = selectedImageScrollView.bounds.width
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) {
                self.interactor?.fetchImage(Image_Request(id: self.images[0].id, size: CGSize(width: width, height: width)))
            }
        }
    }
    
    func displayMainImage(response: Image_Response) {
        selectedImage = response.image
    }
    
    func addAlbumPreview(album: PhotoAlbum) {
        albums.append(album)
    }
}

extension SnapImagePickerViewController: UIScrollViewDelegate {
    func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
        return selectedImageView
    }
}

extension SnapImagePickerViewController {
    private func setupGestureRecognizers() {
        mainScrollView?.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(pan(_:)))
        gesture.delegate = self
        albumCollectionView?.addGestureRecognizer(gesture)
    }
    
    func pan(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .Changed:
            let translation = recognizer.translationInView(mainScrollView)
            if let old = mainScrollView?.contentOffset.y
               where old - translation.y > 0 {
                mainScrollView?.contentOffset = CGPoint(x: 0, y: old - translation.y)
                recognizer.setTranslation(CGPointZero, inView: mainScrollView)
            }
        case .Ended:
            if let offset = mainScrollView?.contentOffset.y,
               let height = selectedImageScrollView?.bounds.height {
                let ratio = (height - offset) / height
                if ratio < OffsetThreshold {
                    state = .Album
                } else {
                    state = .Image
                }
            }
        default: break
        }
    }
    
    private func setMainOffsetFor(state: DisplayState) {
        if let selectedImageScrollView = selectedImageScrollView,
           let mainScrollView = mainScrollView {
            let height = selectedImageScrollView.bounds.height
            mainScrollView.setContentOffset(CGPoint(x: mainScrollView.contentOffset.x, y: height * CGFloat(state.rawValue)), animated: true)
            
            switch state {
            case .Image:
                selectedImageScrollView.userInteractionEnabled = true
            case .Album:
                selectedImageScrollView.userInteractionEnabled = false
            }
        }
    }
}

extension SnapImagePickerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        let albumCanScrollFurtherUp = albumCollectionView?.contentOffset.y > 0
        var userIsScrollingUpwards = false
        if let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer {
            userIsScrollingUpwards = panRecognizer.translationInView(albumCollectionView).y > 0
        }
        if userIsScrollingUpwards {
            albumCollectionView?.bounces = false
        } else {
            albumCollectionView?.bounces = true
        }

        return state == .Image || (userIsScrollingUpwards && !albumCanScrollFurtherUp)
    }
}

extension SnapImagePickerViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        print("Pressed \(indexPath.row)")
        currentlySelectedAlbum = indexPath.row
        hideCollectionsView()
    }
}