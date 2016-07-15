import Photos

protocol SnapImagePickerEntityGatewayProtocol: class {
    func loadInitialAlbum(type: AlbumType)
    func loadAlbumImageWithType(type: AlbumType, withTargetSize targetSize: CGSize, atIndex: Int) -> Bool
    func loadImageWithLocalIdentifier(localIdentifier: String) -> Bool
    func clearPendingRequests()
}